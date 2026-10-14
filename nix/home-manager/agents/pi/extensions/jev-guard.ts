/**
 * jev-guard — gate dangerous pi actions (deterministic rules + jev)
 *
 * See ../jev-guard-plan.md for the full design. In one paragraph:
 *
 * Every `bash` call is parsed with `shfmt --to-json` (mvdan/sh). Write-class
 * commands (rm, mv, cp, redirects, tee, find -delete, ...) have their targets
 * resolved against a *write zone* = session cwd (only when it is inside a
 * project repo) + temp dirs + ~/.cache. Targets outside the zone confirm;
 * zone roots, `~`, `/`, the cwd itself and their ancestors hard-block;
 * anything the parser cannot resolve (variables, command substitution, any
 * relative path after a `cd`) confirms. Publishing (`git push`, `jj git push`,
 * `gh pr merge`, `npm publish`, ...) confirms. Unrecoverable repo-state
 * destruction (`rm .git`, `jj op abandon`, `git reflog expire`, ...)
 * hard-blocks. In parallel, the TypeSafe `jev-latest` classifier gives a
 * second opinion on every bash call; it can raise allow -> confirm, never
 * lower. `write`/`edit` tools get the zone check only.
 *
 * Nothing is remembered across prompts. Headless (no UI) turns confirm into
 * block. `PI_GUARD=off` disables everything, `PI_GUARD=log` only logs.
 * Every decision is appended to ~/.pi/agent/jev-guard/decisions.jsonl.
 *
 * Pure decision logic (`decide`, `classifyPath`, ...) is exported for the
 * bun test harness; the default export wires it into pi.
 */

import { execFile } from "node:child_process";
import {
	appendFileSync,
	existsSync,
	mkdirSync,
	readFileSync,
	realpathSync,
	renameSync,
	statSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, isAbsolute, join, resolve as pathResolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ---------------------------------------------------------------------------
// Tunables
// ---------------------------------------------------------------------------

const STATUS_KEY = "guard";
/** jev bool answers at or above this probability raise allow -> confirm. */
export const JEV_CONFIRM_P = 0.5;
const JEV_TIMEOUT_MS = 1500;
const JEV_BREAKER_FAILURES = 3;
const JEV_BREAKER_COOLDOWN_MS = 10 * 60_000;
const CONFIRM_TIMEOUT_MS = 600_000;
const SHFMT_TIMEOUT_MS = 5000;
const LOG_MAX_BYTES = 8 * 1024 * 1024;
/** Max depth for `bash -c`, aliases and session-script recursion. */
const MAX_DEPTH = 4;
const MAX_TITLE_CMD = 240;

// Substituted by nix at build time (see plugins.nix `substitutions`). When the
// placeholder survives (e.g. running from the repo checkout) we fall back to
// PATH lookup.
const SHFMT_BUILD = "@shfmt@";
const JEV_BUILD = "@jev@"; // "true" | "false"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type Verdict = "allow" | "confirm" | "hard-block";
const RANK: Record<Verdict, number> = { allow: 0, confirm: 1, "hard-block": 2 };
export function maxVerdict(a: Verdict, b: Verdict): Verdict {
	return RANK[a] >= RANK[b] ? a : b;
}

export type FindingClass =
	| "publish"
	| "write-outside"
	| "write-root"
	| "unresolvable"
	| "repo-loss"
	| "raw-git"
	| "self-protect"
	| "script"
	| "parse-error"
	| "no-shfmt"
	| "jev";

export interface Finding {
	verdict: Verdict;
	cls: FindingClass;
	reason: string;
	/** Resolved absolute path, when the finding is about one. */
	target?: string;
}

export interface Decision {
	verdict: Verdict;
	findings: Finding[];
	/** Resolved absolute targets of write-class commands (for jev + log). */
	resolved: string[];
	/** Raw words we could not resolve (for jev + log). */
	unresolved: string[];
	/** `cd`/`pushd`/`popd` appears anywhere in the command. */
	hasCd: boolean;
	/** The last top-level command is `cd`/`pushd` (stale-cd note). */
	lastIsCd: boolean;
	/** "git put -> git push origin HEAD" style expansions that were applied. */
	aliasExpansions: string[];
	/** Contents of session-written scripts this command executes. */
	scripts: string[];
}

export type Vcs = "jj-colocated" | "jj" | "git" | null;

/** Filesystem access used for resolution; injectable so tests can fake it. */
export interface GuardFs {
	exists(p: string): boolean;
	isDir(p: string): boolean;
	realpath(p: string): string;
	read(p: string): string | null;
}

export interface GuardEnv {
	/** realpath of the session cwd. */
	cwd: string;
	home: string;
	/** $TMPDIR / os.tmpdir(), realpath'd. */
	tmpdir: string;
	/** Zone roots, realpath'd. Includes cwd only in project mode. */
	zone: string[];
	projectMode: boolean;
	vcs: Vcs;
	gitAliases: Record<string, string>;
	jjAliases: Record<string, string[]>;
	fs: GuardFs;
	parse: (command: string) => Promise<ShNode | null>;
	/** resolved path -> content (null = edited this session; read from disk). */
	sessionScripts: Map<string, string | null>;
	/** Directory the guard itself writes to; exempt from .pi self-protection. */
	guardDir: string;
}

/** Loosely typed shfmt JSON node. */
export type ShNode = Record<string, any>;

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

/** Strip a trailing slash (except for "/"). */
export function norm(p: string): string {
	if (p.length > 1 && p.endsWith("/")) return p.replace(/\/+$/, "") || "/";
	return p;
}

/** `p` is strictly inside `root`. */
export function isInside(p: string, root: string): boolean {
	p = norm(p);
	root = norm(root);
	if (p === root) return false;
	return root === "/" ? p.startsWith("/") : p.startsWith(`${root}/`);
}

export const realFs: GuardFs = {
	exists: (p) => existsSync(p),
	isDir: (p) => {
		try {
			return statSync(p).isDirectory();
		} catch {
			return false;
		}
	},
	realpath: (p) => {
		try {
			return realpathSync(p);
		} catch {
			return p;
		}
	},
	read: (p) => {
		try {
			return readFileSync(p, "utf8");
		} catch {
			return null;
		}
	},
};

/** realpath of the longest existing prefix, with the rest re-appended. */
export function realpathPrefix(p: string, fs: GuardFs): string {
	let cur = norm(p);
	const rest: string[] = [];
	while (!fs.exists(cur)) {
		const parent = dirname(cur);
		if (parent === cur) return norm(p);
		rest.unshift(basename(cur));
		cur = parent;
	}
	const real = norm(fs.realpath(cur));
	return rest.length ? norm(join(real, ...rest)) : real;
}

// ---------------------------------------------------------------------------
// Zone classification
// ---------------------------------------------------------------------------

export interface Target {
	/** Raw word as written. */
	raw: string;
	/** Resolved absolute path (dirname when `glob`). */
	path: string;
	/** Final component was a glob: the target is "everything in `path`". */
	glob: boolean;
}

export type PathKind = "allow" | "hard-root" | "zone-root-glob" | "outside" | "vcs-meta" | "pi-meta";

export interface PathClass {
	kind: PathKind;
	/** The guarded root that triggered hard-root / zone-root-glob. */
	root?: string;
}

/**
 * Classify a resolved write target against the zone model (plan §4.2 / §5):
 *
 *   inside a zone root (not .git/.jj/.pi)            -> allow
 *   equals / ancestor of a guarded root               -> hard-root (hard-block)
 *   glob directly at a zone root or the cwd           -> zone-root-glob (confirm)
 *   inside any .git / .jj                             -> vcs-meta (hard-block)
 *   under any .pi (except the guard's own dir)        -> pi-meta (hard-block)
 *   anything else                                     -> outside (confirm)
 *
 * Guarded roots are the zone roots, `~`, `/` and the session cwd (the cwd is
 * guarded even in no-project mode: deleting it is the incident).
 */
export function classifyPath(t: Target, env: GuardEnv): PathClass {
	const p = norm(t.path);
	const comps = p.split("/").filter(Boolean);
	if (comps.includes(".git") || comps.includes(".jj")) return { kind: "vcs-meta" };
	if (comps.includes(".pi") && p !== norm(env.guardDir) && !isInside(p, env.guardDir)) {
		return { kind: "pi-meta" };
	}

	// Order matters only for messages: name the most specific root first.
	const hard = uniq([env.cwd, env.home, "/", ...env.zone].map(norm));
	const equals = hard.find((r) => r === p);
	if (equals) {
		if (!t.glob || p === norm(env.home) || p === "/") return { kind: "hard-root", root: equals };
		// "everything in a zone root": confirm unless that also wipes another guarded root.
		const alsoAncestorOf = hard.find((r) => isInside(r, p));
		if (alsoAncestorOf) return { kind: "hard-root", root: alsoAncestorOf };
		return { kind: "zone-root-glob", root: equals };
	}
	const ancestorOf = hard.find((r) => isInside(r, p));
	if (ancestorOf) return { kind: "hard-root", root: ancestorOf };
	if (env.zone.some((z) => isInside(p, z))) return { kind: "allow" };
	return { kind: "outside" };
}

function describeRoot(root: string, env: GuardEnv): string {
	const r = norm(root);
	if (r === norm(env.cwd)) return "the session's working directory";
	if (r === norm(env.home)) return "your home directory";
	if (r === "/") return "the filesystem root";
	return `a protected zone root (${r})`;
}

function zoneDescription(env: GuardEnv): string {
	return env.projectMode ? `the project ${env.cwd}` : "the write zone (no project: temp + cache only)";
}

function uniq<T>(xs: T[]): T[] {
	return [...new Set(xs)];
}

// ---------------------------------------------------------------------------
// Word -> literal
// ---------------------------------------------------------------------------

export type WordLit =
	| { kind: "lit"; value: string; glob: boolean; raw: string }
	| { kind: "cwd"; raw: string }
	| { kind: "script"; content: string; path: string; raw: string }
	| { kind: "unresolvable"; raw: string; why: string };

const GLOB_RE = /[*?[]/;
const BRACE_RE = /\{[^{}]*(,|\.\.)[^{}]*\}/;

function isSimpleParam(p: ShNode): boolean {
	return !(p.Excl || p.Length || p.Width || p.Index || p.Slice || p.Repl || p.Exp);
}

/** The single CallExpr in a statement list, if that is all there is. */
function singleCall(stmts: ShNode[] | undefined): ShNode | null {
	if (!stmts || stmts.length !== 1) return null;
	const s = stmts[0];
	if (s?.Cmd?.Type !== "CallExpr" || (s.Redirs && s.Redirs.length)) return null;
	return s.Cmd;
}

/** Best-effort reconstruction of a word's source text, for messages. */
export function wordRaw(word: ShNode | undefined): string {
	if (!word?.Parts) return "";
	const out: string[] = [];
	for (const p of word.Parts) {
		switch (p.Type) {
			case "Lit":
				out.push(p.Value ?? "");
				break;
			case "SglQuoted":
				out.push(`'${p.Value ?? ""}'`);
				break;
			case "DblQuoted":
				out.push(`"${wordRaw({ Parts: p.Parts })}"`);
				break;
			case "ParamExp":
				out.push(p.Short ? `$${p.Param?.Value ?? ""}` : `\${${p.Param?.Value ?? ""}${isSimpleParam(p) ? "" : "…"}}`);
				break;
			case "CmdSubst": {
				const c = singleCall(p.Stmts);
				const inner = c ? c.Args.map((a: ShNode) => wordRaw(a)).join(" ") : "…";
				out.push(p.Backquotes ? `\`${inner}\`` : `$(${inner})`);
				break;
			}
			case "ArithmExp":
				out.push("$((…))");
				break;
			case "ProcSubst":
				out.push(`${p.Op ?? "<"}(…)`);
				break;
			default:
				out.push("…");
		}
	}
	return out.join("");
}

/** Key under which a session-written script is tracked (realpath'd absolute path). */
function scriptKey(v: string, env: GuardEnv): string {
	const expanded = v === "~" || v.startsWith("~/") ? env.home + v.slice(1) : v;
	return realpathPrefix(resolveLitPath(expanded, env), env.fs);
}

/**
 * Candidate keys for a script path. A relative path after a `cd` could name
 * any tracked script with that basename (`cd sub && ./x.sh`), so all of them
 * are candidates, plus the session-cwd resolution (the `cd` may have failed).
 */
function scriptKeys(v: string, env: GuardEnv, hasCd: boolean): string[] {
	const keys = [scriptKey(v, env)];
	if (hasCd && !isAbsolute(v) && !(v === "~" || v.startsWith("~/"))) {
		const base = basename(v);
		for (const k of env.sessionScripts.keys()) if (basename(k) === base && !keys.includes(k)) keys.push(k);
	}
	return keys;
}

function trackedScript(path: string, env: GuardEnv): string | null | undefined {
	if (!env.sessionScripts.has(path)) return undefined;
	const c = env.sessionScripts.get(path);
	if (c != null) return c;
	return env.fs.read(path);
}

/**
 * Reduce a word to a literal string, applying only the expansions the plan
 * allows (`~`, `~/`, `$HOME`, `$TMPDIR`). `$PWD` / `$(pwd)` as the *whole* word
 * mean "the cwd" unless a `cd` appears anywhere (then unresolvable).
 */
export function wordLiteral(word: ShNode | undefined, env: GuardEnv, hasCd: boolean): WordLit {
	const raw = wordRaw(word);
	let parts: ShNode[] = word?.Parts ?? [];
	let quotedAll = false;
	if (parts.length === 1 && parts[0].Type === "DblQuoted") {
		parts = parts[0].Parts ?? [];
		quotedAll = true;
	}
	if (parts.length === 1) {
		const p = parts[0];
		if (p.Type === "ParamExp" && p.Param?.Value === "PWD" && isSimpleParam(p)) {
			return hasCd ? { kind: "unresolvable", raw, why: "$PWD after a cd" } : { kind: "cwd", raw };
		}
		if (p.Type === "CmdSubst") {
			const c = singleCall(p.Stmts);
			const argv = c ? c.Args.map((a: ShNode) => wordLiteral(a, env, hasCd)) : [];
			const lits = argv.every((a: WordLit) => a.kind === "lit") ? argv.map((a: any) => a.value as string) : null;
			if (lits && lits.length === 1 && lits[0] === "pwd") {
				return hasCd ? { kind: "unresolvable", raw, why: "$(pwd) after a cd" } : { kind: "cwd", raw };
			}
			if (lits && lits.length === 2 && lits[0] === "cat" && !hasCd) {
				const path = scriptKey(lits[1], env);
				const content = trackedScript(path, env);
				if (content != null) return { kind: "script", content, path, raw };
			}
			return { kind: "unresolvable", raw, why: "command substitution" };
		}
	}

	let out = "";
	let glob = false;
	const visit = (ps: ShNode[], quoted: boolean, first: boolean): WordLit | null => {
		for (let i = 0; i < ps.length; i++) {
			const p = ps[i];
			const isFirst = first && i === 0;
			switch (p.Type) {
				case "Lit": {
					let v: string = p.Value ?? "";
					if (!quoted) {
						if (isFirst && v.startsWith("~")) {
							if (v === "~" || v.startsWith("~/")) v = env.home + v.slice(1);
							else return { kind: "unresolvable", raw, why: "~user expansion" };
						}
						if (BRACE_RE.test(v)) return { kind: "unresolvable", raw, why: "brace expansion" };
						if (GLOB_RE.test(v.replace(/\\./g, ""))) glob = true;
						v = v.replace(/\\(.)/gs, "$1");
					} else {
						v = v.replace(/\\([$`"\\\n])/g, "$1");
					}
					out += v;
					break;
				}
				case "SglQuoted":
					out += p.Value ?? "";
					break;
				case "DblQuoted": {
					const r = visit(p.Parts ?? [], true, false);
					if (r) return r;
					break;
				}
				case "ParamExp": {
					const name: string = p.Param?.Value ?? "";
					if (!isSimpleParam(p)) return { kind: "unresolvable", raw, why: `\${${name}…} expansion` };
					if (name === "HOME") out += env.home;
					else if (name === "TMPDIR") out += env.tmpdir;
					else if (name === "PWD") return { kind: "unresolvable", raw, why: "$PWD inside a longer path" };
					else return { kind: "unresolvable", raw, why: `variable $${name}` };
					break;
				}
				case "CmdSubst":
					return { kind: "unresolvable", raw, why: "command substitution" };
				case "ArithmExp":
					return { kind: "unresolvable", raw, why: "arithmetic expansion" };
				case "ProcSubst":
					return { kind: "unresolvable", raw, why: "process substitution" };
				default:
					return { kind: "unresolvable", raw, why: `${p.Type ?? "unknown"} word part` };
			}
		}
		return null;
	};
	const bad = visit(parts, quotedAll, !quotedAll);
	if (bad) return bad;
	return { kind: "lit", value: out, glob, raw };
}

/** Absolute path for a literal (no glob handling). */
function resolveLitPath(v: string, env: GuardEnv): string {
	return norm(isAbsolute(v) ? pathResolve(v) : pathResolve(env.cwd, v));
}

export type Resolved = { ok: true; target: Target } | { ok: false; raw: string; why: string };

/** Resolve a word to a filesystem target per plan §4.1. */
export function resolveTarget(word: ShNode | undefined, env: GuardEnv, hasCd: boolean): Resolved {
	const lit = wordLiteral(word, env, hasCd);
	if (lit.kind === "cwd") return { ok: true, target: { raw: lit.raw, path: env.cwd, glob: false } };
	if (lit.kind === "script") return { ok: false, raw: lit.raw, why: "command substitution" };
	if (lit.kind === "unresolvable") return { ok: false, raw: lit.raw, why: lit.why };
	const v = lit.value;
	if (v === "") return { ok: false, raw: lit.raw, why: "empty word" };
	if (!isAbsolute(v) && hasCd) return { ok: false, raw: lit.raw, why: "relative path after a cd" };
	let glob = false;
	let p = resolveLitPath(v, env);
	if (lit.glob) {
		const comps = v.split("/");
		const idx = comps.findIndex((c) => GLOB_RE.test(c));
		if (idx !== comps.length - 1) return { ok: false, raw: lit.raw, why: "glob in a non-final path component" };
		glob = true;
		p = norm(dirname(p));
	}
	return { ok: true, target: { raw: lit.raw, path: realpathPrefix(p, env.fs), glob } };
}

// ---------------------------------------------------------------------------
// Command tables
// ---------------------------------------------------------------------------

/** Wrappers whose real command follows their own flags. */
const WRAPPERS: Record<string, { valueFlags: string[]; skipAssigns?: boolean; leadingValue?: boolean }> = {
	sudo: { valueFlags: ["-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U", "-T"] },
	doas: { valueFlags: ["-u", "-C"] },
	env: { valueFlags: ["-u", "-C", "-S", "--unset", "--chdir", "--split-string"], skipAssigns: true },
	command: { valueFlags: [] },
	builtin: { valueFlags: [] },
	exec: { valueFlags: ["-a"] },
	nohup: { valueFlags: [] },
	nice: { valueFlags: ["-n", "--adjustment"] },
	ionice: { valueFlags: ["-c", "-n", "-p"] },
	time: { valueFlags: ["-f", "-o", "--format", "--output"] },
	timeout: { valueFlags: ["-k", "-s", "--kill-after", "--signal"], leadingValue: true },
	stdbuf: { valueFlags: ["-i", "-o", "-e"] },
	caffeinate: { valueFlags: ["-t", "-w"] },
	unbuffer: { valueFlags: [] },
	chronic: { valueFlags: [] },
};

/** Flags that consume the next word, per write-class command. */
const VALUE_FLAGS: Record<string, string[]> = {
	truncate: ["-s", "--size", "-r", "--reference"],
	shred: ["-n", "--iterations", "-s", "--size"],
	install: ["-m", "--mode", "-o", "--owner", "-g", "--group", "-t", "--target-directory", "-S", "--suffix"],
	ln: ["-t", "--target-directory", "-S", "--suffix"],
	cp: ["-t", "--target-directory", "-S", "--suffix"],
	mv: ["-t", "--target-directory", "-S", "--suffix"],
	rsync: ["-e", "--rsh", "--exclude", "--include", "--exclude-from", "--include-from", "--files-from", "-T", "--temp-dir", "--log-file", "-B", "--block-size", "--bwlimit", "--timeout", "--max-size", "--min-size", "--chmod", "--chown", "--backup-dir", "--suffix", "--partial-dir", "--compare-dest", "--copy-dest", "--link-dest", "--filter", "-f", "--password-file", "--port", "--sockopts", "--out-format", "--iconv", "--usermap", "--groupmap"],
	git: ["-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env", "--list-cmds", "--super-prefix"],
	jj: ["-R", "--repository", "--at-op", "--at-operation", "--config", "--config-file", "--config-toml", "--color"],
	xargs: ["-I", "-i", "-L", "-n", "-P", "-s", "-d", "-E", "-a", "--arg-file", "--delimiter", "--max-args", "--max-lines", "--max-procs", "--max-chars", "--replace", "--eof", "--process-slot-var"],
	bash: ["--rcfile", "--init-file", "-O", "+O", "-o", "+o"],
	sh: ["-o", "+o"],
	zsh: ["-o", "+o"],
	dash: ["-o", "+o"],
	ksh: ["-o", "+o"],
};

const SHELLS = new Set(["bash", "sh", "zsh", "dash", "ksh", "mksh", "fish"]);
const INTERPRETERS = new Set([
	"python", "python3", "python2", "node", "bun", "deno", "ruby", "perl", "php", "lua", "tclsh", "osascript", "uv", "npx", "bunx", "tsx", "ts-node",
]);
const WRITE_VERBS: Record<string, string> = {
	rm: "Delete", rmdir: "Delete", unlink: "Delete", shred: "Shred", truncate: "Truncate",
	mv: "Move", cp: "Copy over", rsync: "Sync into", install: "Install into", ln: "Link over", tee: "Write", dd: "Write",
	find: "Delete under", redirect: "Write",
};

const CD_CMDS = new Set(["cd", "pushd", "popd"]);

/** Package/registry publishing subcommands (class 1). */
const PUBLISH_SUBCMDS: Record<string, string[]> = {
	npm: ["publish", "unpublish", "deprecate"],
	pnpm: ["publish", "unpublish", "deprecate"],
	yarn: ["publish", "unpublish", "deprecate"],
	bun: ["publish"],
	cargo: ["publish", "yank"],
	gem: ["push", "yank"],
	twine: ["upload"],
	docker: ["push"],
	podman: ["push"],
	helm: ["push"],
	nix: ["copy"],
	crane: ["push", "copy"],
	oras: ["push"],
};

/** Redirect operators that write to the target word. */
const WRITE_REDIRS = new Set([">", ">>", "<>", ">|", "&>", "&>>"]);

// ---------------------------------------------------------------------------
// AST walking
// ---------------------------------------------------------------------------

interface WordInfo {
	word: ShNode;
	lit: WordLit;
	/** Literal value, if `lit.kind === "lit"`. */
	v?: string;
}

interface Sub {
	script: string;
	label: string;
}

interface WalkState {
	env: GuardEnv;
	hasCd: boolean;
	findings: Finding[];
	resolved: string[];
	unresolved: string[];
	aliasExpansions: string[];
	scripts: string[];
	subs: Sub[];
	depth: number;
}

function words(args: ShNode[] | undefined, st: WalkState): WordInfo[] {
	return (args ?? []).map((w) => {
		const lit = wordLiteral(w, st.env, st.hasCd);
		return { word: w, lit, v: lit.kind === "lit" ? lit.value : undefined };
	});
}

function isFlag(w: WordInfo): boolean {
	return w.v !== undefined && w.v.length > 1 && w.v.startsWith("-") && w.lit.kind === "lit";
}

/** Split `argv[1..]` into flags and operands; `--` ends flag parsing. */
function splitOperands(rest: WordInfo[], valueFlags: string[] = []): { flags: string[]; operands: WordInfo[]; valueOf: Map<string, WordInfo> } {
	const flags: string[] = [];
	const operands: WordInfo[] = [];
	const valueOf = new Map<string, WordInfo>();
	let onlyOperands = false;
	for (let i = 0; i < rest.length; i++) {
		const w = rest[i];
		if (onlyOperands) {
			operands.push(w);
			continue;
		}
		if (w.v === "--") {
			onlyOperands = true;
			continue;
		}
		if (isFlag(w)) {
			const f = w.v as string;
			flags.push(f);
			const eq = f.indexOf("=");
			if (eq > 0 && f.startsWith("--")) {
				const name = f.slice(0, eq);
				if (valueFlags.includes(name)) valueOf.set(name, { ...w, v: f.slice(eq + 1), lit: { kind: "lit", value: f.slice(eq + 1), glob: false, raw: f.slice(eq + 1) } });
				continue;
			}
			if (valueFlags.includes(f) && i + 1 < rest.length) {
				valueOf.set(f, rest[i + 1]);
				i++;
			}
			continue;
		}
		operands.push(w);
	}
	return { flags, operands, valueOf };
}

/** Drop leading wrappers (`sudo`, `env X=1`, `nohup`, ...); returns the real argv. */
/** Wrapper flags that run the inner command in another directory (a `cd` in disguise). */
const WRAPPER_CHDIR: Record<string, RegExp> = {
	env: /^(-C|--chdir(=.*)?)$/,
	sudo: /^(-D|--chdir(=.*)?)$/,
};

/** Drop wrapper commands (sudo, env, nice, …); `out.chdir` reports an `env -C`-style directory change. */
function stripWrappers(argv: WordInfo[], out?: { chdir: boolean }): WordInfo[] {
	for (let guard = 0; guard < 8 && argv.length; guard++) {
		const name = cmdName(argv[0]);
		const wr = name ? WRAPPERS[name] : undefined;
		if (!wr) return argv;
		const chdirRe = name ? WRAPPER_CHDIR[name] : undefined;
		let i = 1;
		let leadingPending = wr.leadingValue === true; // e.g. `timeout [flags] DURATION cmd`
		for (; i < argv.length; i++) {
			const w = argv[i];
			if (w.v === "--") {
				i++;
				break;
			}
			if (isFlag(w)) {
				if (out && chdirRe && w.v !== undefined && chdirRe.test(w.v)) out.chdir = true;
				if (wr.valueFlags.includes(w.v as string)) i++;
				continue;
			}
			if (wr.skipAssigns && w.v !== undefined && /^[A-Za-z_][A-Za-z0-9_]*=/.test(w.v)) continue;
			if (leadingPending) {
				leadingPending = false;
				continue;
			}
			break;
		}
		argv = argv.slice(i);
	}
	return argv;
}

/** Command name (basename) of a literal word, or null. */
function cmdName(w: WordInfo | undefined): string | null {
	if (!w || w.lit.kind !== "lit" || w.v === undefined || w.v === "") return null;
	return w.v.includes("/") ? basename(w.v) : w.v;
}

function addFinding(st: WalkState, f: Finding) {
	st.findings.push(f);
}

/** Classify one write target and record the finding. */
function judgeTarget(st: WalkState, verb: string, res: Resolved, opts: { destDir?: boolean; find?: boolean } = {}) {
	const env = st.env;
	if (!res.ok) {
		st.unresolved.push(res.raw);
		addFinding(st, {
			verdict: "confirm",
			cls: "unresolvable",
			reason: `${verb} ${res.raw}: target is not static (${res.why}); this call runs in ${env.cwd}`,
		});
		return;
	}
	let t = res.target;
	// mv/cp/install INTO an existing directory writes dir/<basename>, not dir.
	if (opts.destDir && !t.glob && env.fs.isDir(t.path)) t = { ...t, path: norm(join(t.path, "<src>")) };
	st.resolved.push(t.glob ? `${t.path}/*` : t.path);
	const c = classifyPath(t, env);
	switch (c.kind) {
		case "allow":
			return;
		case "vcs-meta":
			addFinding(st, { verdict: "hard-block", cls: "repo-loss", target: t.path, reason: `refused: ${t.raw} is ${t.path}, inside a .git/.jj directory — unrecoverable repo state` });
			return;
		case "pi-meta":
			addFinding(st, { verdict: "hard-block", cls: "self-protect", target: t.path, reason: `refused: ${t.raw} is ${t.path}; writes under .pi/ are protected` });
			return;
		case "hard-root":
			if (opts.find && c.root && norm(t.path) === norm(c.root) && env.zone.includes(norm(c.root))) {
				// find starting at a zone root deletes *matching* entries beneath it, not the root.
				return;
			}
			if (opts.find) {
				addFinding(st, { verdict: "confirm", cls: "write-outside", target: t.path, reason: `${verb} ${t.path} (${describeRoot(c.root ?? t.path, env)}, outside ${zoneDescription(env)})?` });
				return;
			}
			addFinding(st, {
				verdict: "hard-block",
				cls: "write-root",
				target: t.path,
				reason:
					norm(t.path) === norm(c.root ?? "")
						? `refused: ${t.raw} is ${t.path}, ${describeRoot(c.root ?? t.path, env)}`
						: `refused: ${t.raw} is ${t.path}, an ancestor of ${c.root} (${describeRoot(c.root ?? "", env)})`,
			});
			return;
		case "zone-root-glob":
			addFinding(st, { verdict: "confirm", cls: "write-root", target: t.path, reason: `${t.raw} expands to everything in ${t.path} (${describeRoot(c.root ?? t.path, env)}). ${verb} all of it?` });
			return;
		case "outside":
			addFinding(st, { verdict: "confirm", cls: "write-outside", target: t.path, reason: `${verb} ${t.glob ? `${t.path}/*` : t.path} (outside ${zoneDescription(env)})?` });
			return;
	}
}

function isShellScript(content: string, path: string, viaShell: boolean): boolean {
	const first = content.split("\n", 1)[0] ?? "";
	if (first.startsWith("#!")) return /\b(ba|z|da|k|mk)?sh\b/.test(first);
	if (/\.(sh|bash|zsh)$/.test(path)) return true;
	return viaShell;
}

/** A session-written script is being executed. */
function judgeScriptExec(st: WalkState, path: string, viaShell: boolean, how: string) {
	const content = trackedScript(path, st.env);
	if (content === undefined) return false; // not tracked
	if (content === null) {
		addFinding(st, { verdict: "confirm", cls: "script", reason: `${how} runs ${path}, which this session edited and whose content is not available yet` });
		return true;
	}
	if (isShellScript(content, path, viaShell)) {
		st.scripts.push(content);
		st.subs.push({ script: content, label: `in ${path}` });
	} else {
		st.scripts.push(content);
		addFinding(st, { verdict: "confirm", cls: "script", reason: `${how} runs ${path}, a non-shell script written this session` });
	}
	return true;
}

/** Handle `bash -c S`, `sh file`, heredoc scripts, `eval`. */
function handleShell(st: WalkState, name: string, argv: WordInfo[], stmt: ShNode | undefined) {
	const { operands, flags } = splitOperands(argv.slice(1), VALUE_FLAGS[name] ?? []);
	if (flags.some((f) => /^-[a-zA-Z]*c/.test(f))) {
		const s = operands[0];
		if (!s) return;
		if (s.lit.kind === "lit") st.subs.push({ script: s.lit.value, label: `in ${name} -c` });
		else if (s.lit.kind === "script") {
			st.scripts.push(s.lit.content);
			st.subs.push({ script: s.lit.content, label: `in ${s.lit.path}` });
		} else {
			// Non-literal script: det says nothing beyond what the AST shows (jev covers it).
			st.unresolved.push(s.lit.raw);
		}
		return;
	}
	// `bash file.sh` / `source file`
	const file = operands[0];
	if (file?.lit.kind === "lit") {
		for (const k of scriptKeys(file.lit.value, st.env, st.hasCd)) if (judgeScriptExec(st, k, true, `${name} ${file.lit.raw}`)) break;
	}
	// `bash <<EOF ... EOF`
	for (const r of stmt?.Redirs ?? []) {
		if ((r.Op === "<<" || r.Op === "<<-") && r.Hdoc) {
			const h = wordLiteral(r.Hdoc, st.env, st.hasCd);
			if (h.kind === "lit") st.subs.push({ script: h.value, label: `in ${name} heredoc` });
		}
	}
}

function handleGit(st: WalkState, argv: WordInfo[], hops: number) {
	const env = st.env;
	const all = argv.slice(1);
	const { operands } = splitOperands(all, VALUE_FLAGS.git);
	const sub = operands[0]?.v;
	if (!sub) return;
	const rest = all.slice(all.indexOf(operands[0]) + 1);
	const alias = env.gitAliases[sub];
	if (alias !== undefined && hops < MAX_DEPTH) {
		st.aliasExpansions.push(`git ${sub} -> ${alias.startsWith("!") ? alias : `git ${alias}`}`);
		if (alias.startsWith("!")) {
			st.subs.push({ script: alias.slice(1), label: `in git alias ${sub}` });
			return;
		}
		const toks = alias.split(/\s+/).filter(Boolean).map((t): WordInfo => ({ word: { Parts: [{ Type: "Lit", Value: t }] }, lit: { kind: "lit", value: t, glob: false, raw: t }, v: t }));
		handleGit(st, [argv[0], ...toks, ...rest], hops + 1);
		return;
	}
	const flags = rest.filter(isFlag).map((w) => w.v as string);
	const ops = rest.filter((w) => !isFlag(w)).map((w) => w.v ?? wordRaw(w.word));
	switch (sub) {
		case "push":
			addFinding(st, { verdict: "confirm", cls: "publish", reason: `git push${ops.length ? ` ${ops.join(" ")}` : ""}${flags.some((f) => /force|-f$/.test(f)) ? " (FORCE)" : ""}: publish to the remote?` });
			return;
		case "send-email":
		case "svn":
			if (sub === "svn" && ops[0] !== "dcommit") return;
			addFinding(st, { verdict: "confirm", cls: "publish", reason: `git ${sub}: publishes commits?` });
			return;
		case "reflog":
			if (ops[0] === "expire" || ops[0] === "delete") addFinding(st, { verdict: "hard-block", cls: "repo-loss", reason: `refused: git reflog ${ops[0]} destroys recovery history` });
			return;
		case "gc":
			if (flags.some((f) => /^--prune=(now|all)/.test(f))) addFinding(st, { verdict: "hard-block", cls: "repo-loss", reason: "refused: git gc --prune=now permanently deletes unreachable objects" });
			return;
		case "update-ref":
			if (flags.includes("-d") || flags.includes("--delete")) addFinding(st, { verdict: "hard-block", cls: "repo-loss", reason: "refused: git update-ref -d deletes a ref without a reflog entry" });
			return;
		case "prune":
			addFinding(st, { verdict: "hard-block", cls: "repo-loss", reason: "refused: git prune permanently deletes unreachable objects" });
			return;
	}
	if (env.vcs === "jj-colocated") {
		const rawGit =
			sub === "checkout" || sub === "switch" || sub === "restore" ||
			(sub === "reset" && flags.some((f) => /^--(hard|merge|keep)$/.test(f))) ||
			(sub === "clean" && flags.some((f) => /^-[a-zA-Z]*f|^--force$/.test(f))) ||
			(sub === "stash" && ["drop", "clear", "pop"].includes(ops[0] ?? ""));
		if (rawGit) {
			addFinding(st, { verdict: "confirm", cls: "raw-git", reason: `git ${sub} in a colocated jj repo: prefer jj; raw git can lose un-snapshotted edits. Continue?` });
		}
	}
}

function handleJj(st: WalkState, argv: WordInfo[], hops: number) {
	const env = st.env;
	const all = argv.slice(1);
	const { operands } = splitOperands(all, VALUE_FLAGS.jj);
	const sub = operands[0]?.v;
	if (!sub) return;
	const rest = all.slice(all.indexOf(operands[0]) + 1);
	const alias = env.jjAliases[sub];
	if (alias && hops < MAX_DEPTH) {
		st.aliasExpansions.push(`jj ${sub} -> jj ${alias.join(" ")}`);
		const toks = alias.map((t): WordInfo => ({ word: { Parts: [{ Type: "SglQuoted", Value: t }] }, lit: { kind: "lit", value: t, glob: false, raw: t }, v: t }));
		handleJj(st, [argv[0], ...toks, ...rest], hops + 1);
		return;
	}
	const ops = rest.filter((w) => !isFlag(w));
	const sub2 = ops[0]?.v;
	if (sub === "git" && sub2 === "push") {
		const what = rest.slice(1).map((w) => w.v ?? wordRaw(w.word)).join(" ");
		addFinding(st, { verdict: "confirm", cls: "publish", reason: `jj git push${what ? ` ${what}` : ""}: publish bookmarks to the remote?` });
		return;
	}
	if ((sub === "op" || sub === "operation") && sub2 === "abandon") {
		addFinding(st, { verdict: "hard-block", cls: "repo-loss", reason: "refused: jj op abandon deletes operation history (unrecoverable)" });
		return;
	}
	if (sub === "util" && sub2 === "gc") {
		addFinding(st, { verdict: "hard-block", cls: "repo-loss", reason: "refused: jj util gc permanently deletes unreachable data" });
		return;
	}
	if (sub === "util" && sub2 === "exec") {
		// jj util exec -- CMD ARGS...: re-dispatch CMD as a command of its own.
		const i = rest.findIndex((w) => w.v === "--");
		const cmd = i >= 0 ? rest.slice(i + 1) : ops.slice(1);
		if (cmd.length) handleArgv(st, cmd, undefined, hops + 1);
	}
}

function handleFind(st: WalkState, argv: WordInfo[]) {
	const rest = argv.slice(1);
	const starts: WordInfo[] = [];
	let i = 0;
	for (; i < rest.length; i++) {
		const w = rest[i];
		if (w.v !== undefined && ["-H", "-L", "-P"].includes(w.v)) continue;
		if (w.v !== undefined && (w.v.startsWith("-") || w.v === "(" || w.v === "!")) break;
		starts.push(w);
	}
	const exprs = rest.slice(i);
	let destructive = false;
	for (let j = 0; j < exprs.length; j++) {
		const e = exprs[j].v;
		if (e === "-delete") destructive = true;
		if (e === "-exec" || e === "-execdir" || e === "-ok" || e === "-okdir") {
			const c = cmdName(exprs[j + 1]);
			if (c && (c in WRITE_VERBS || c in WRAPPERS || SHELLS.has(c))) destructive = true;
			if (!c) destructive = true; // unknown exec target
		}
	}
	if (!destructive) return;
	const targets = starts.length ? starts : [{ word: { Parts: [{ Type: "Lit", Value: "." }] }, lit: { kind: "lit", value: ".", glob: false, raw: "." } as WordLit, v: "." }];
	for (const t of targets) judgeTarget(st, "Delete under", resolveTarget(t.word, st.env, st.hasCd), { find: true });
}

/** Dispatch one argv (already a list of WordInfo). `stmt` carries redirects/heredocs. */
function handleArgv(st: WalkState, argv0: WordInfo[], stmt: ShNode | undefined, hops = 0) {
	if (!argv0.length || hops > MAX_DEPTH) return;
	const argv = stripWrappers(argv0);
	if (!argv.length) return;
	const env = st.env;
	const head = argv[0];
	const name = cmdName(head);

	// Direct execution of a session-written script: ./x.sh or /abs/x.sh
	if (head.lit.kind === "lit" && head.v !== undefined && head.v.includes("/")) {
		for (const k of scriptKeys(head.v, env, st.hasCd)) if (judgeScriptExec(st, k, false, head.lit.raw)) return;
	}
	if (!name) return; // non-literal command: jev's call

	if (CD_CMDS.has(name)) return;
	if (SHELLS.has(name) || name === "eval" || name === "source" || name === ".") {
		if (name === "eval") {
			const ws = argv.slice(1).map((w) => w.lit);
			if (ws.length && ws.every((w) => w.kind === "lit")) st.subs.push({ script: ws.map((w: any) => w.value).join(" "), label: "in eval" });
			else for (const w of ws) if (w.kind !== "lit") st.unresolved.push(w.raw);
			return;
		}
		handleShell(st, name === "." ? "source" : name, argv, stmt);
		return;
	}
	if (INTERPRETERS.has(name)) {
		for (const w of argv.slice(1)) {
			if (w.lit.kind === "lit" && w.v && !w.v.startsWith("-")) {
				for (const k of scriptKeys(w.v, env, st.hasCd)) if (judgeScriptExec(st, k, false, `${name} ${w.lit.raw}`)) return;
			}
		}
		// fall through: `bun publish`, `npx ...` etc. are handled below
	}

	switch (name) {
		case "git":
			handleGit(st, argv, hops);
			return;
		case "jj":
			handleJj(st, argv, hops);
			return;
		case "gh": {
			const ops = argv.slice(1).filter((w) => !isFlag(w)).map((w) => w.v ?? "");
			const [a, b] = ops;
			if ((a === "pr" && b === "merge") || (a === "release" && b && !["list", "view", "download"].includes(b)) || (a === "repo" && ["delete", "archive", "rename", "sync"].includes(b ?? ""))) {
				addFinding(st, { verdict: "confirm", cls: "publish", reason: `gh ${a} ${b}: changes the remote repository. Continue?` });
			}
			return;
		}
		case "xargs": {
			const { operands } = splitOperands(argv.slice(1), VALUE_FLAGS.xargs);
			const inner = stripWrappers(operands);
			const c = cmdName(inner[0]);
			if (c && (c in WRITE_VERBS || SHELLS.has(c) || c === "git" || c === "jj")) {
				st.unresolved.push(`xargs ${c}`);
				addFinding(st, { verdict: "confirm", cls: "unresolvable", reason: `xargs ${c}: targets come from stdin and cannot be checked; this call runs in ${env.cwd}. Continue?` });
			}
			return;
		}
		case "find":
			handleFind(st, argv);
			return;
		case "dd": {
			for (const w of argv.slice(1)) {
				if (w.lit.kind === "lit" && w.v?.startsWith("of=")) {
					const v = w.v.slice(3);
					if (v.startsWith("/dev/")) {
						if (/^\/dev\/(null|zero|std(out|err)|fd\/\d+)$/.test(v)) continue;
						addFinding(st, { verdict: "hard-block", cls: "repo-loss", reason: `refused: dd of=${v} writes to a device` });
						return;
					}
					const fake = { Parts: [{ Type: "Lit", Value: v }] };
					judgeTarget(st, "Write", resolveTarget(fake, env, st.hasCd));
				} else if (w.lit.kind !== "lit" && wordRaw(w.word).startsWith("of=")) {
					judgeTarget(st, "Write", { ok: false, raw: w.lit.raw, why: "non-literal of=" });
				}
			}
			return;
		}
	}

	if (name in PUBLISH_SUBCMDS) {
		const ops = argv.slice(1).filter((w) => !isFlag(w)).map((w) => w.v ?? "");
		const pub = ops.find((o) => PUBLISH_SUBCMDS[name].includes(o));
		if (pub) addFinding(st, { verdict: "confirm", cls: "publish", reason: `${name} ${pub}: publishes to a registry/remote. Continue?` });
		return;
	}
	if (name.startsWith("mkfs") || name === "wipefs" || name === "fdisk" || name === "parted" || name === "diskutil") {
		addFinding(st, { verdict: "hard-block", cls: "repo-loss", reason: `refused: ${name} destroys a filesystem/device` });
		return;
	}

	const verb = WRITE_VERBS[name];
	if (!verb) return;
	const { flags, operands, valueOf } = splitOperands(argv.slice(1), VALUE_FLAGS[name] ?? []);
	const res = (w: WordInfo) => resolveTarget(w.word, env, st.hasCd);
	switch (name) {
		case "rm":
		case "rmdir":
		case "unlink":
		case "shred":
		case "truncate":
			for (const w of operands) judgeTarget(st, verb, res(w));
			return;
		case "tee":
			for (const w of operands) if (w.v !== "-") judgeTarget(st, verb, res(w));
			return;
		case "mv": {
			const tdir = valueOf.get("-t") ?? valueOf.get("--target-directory");
			const srcs = tdir ? operands : operands.slice(0, -1);
			const dest = tdir ?? operands[operands.length - 1];
			for (const w of srcs) judgeTarget(st, verb, res(w));
			if (dest && operands.length >= (tdir ? 1 : 2)) judgeTarget(st, "Move into", res(dest), { destDir: true });
			return;
		}
		case "cp":
		case "install":
		case "rsync": {
			const tdir = valueOf.get("-t") ?? valueOf.get("--target-directory");
			const dest = tdir ?? (operands.length >= 2 ? operands[operands.length - 1] : undefined);
			if (!dest) return;
			if (name === "rsync" && dest.v !== undefined && /^[^/]*:/.test(dest.v)) {
				addFinding(st, { verdict: "confirm", cls: "publish", reason: `rsync to remote ${dest.v}. Continue?` });
				return;
			}
			const r = res(dest);
			if (name === "rsync" && flags.some((f) => f.startsWith("--delete")) && r.ok) {
				judgeTarget(st, "Sync with --delete into", { ok: true, target: { ...r.target, glob: true } });
				return;
			}
			judgeTarget(st, verb, r, { destDir: true });
			return;
		}
		case "ln": {
			const tdir = valueOf.get("-t") ?? valueOf.get("--target-directory");
			const force = flags.some((f) => /^-[a-zA-Z]*f|^--force$/.test(f));
			if (!force && !tdir) return;
			const dest = tdir ?? (operands.length >= 2 ? operands[operands.length - 1] : undefined);
			if (dest) judgeTarget(st, verb, res(dest), { destDir: true });
			return;
		}
	}
}

function handleRedirs(st: WalkState, stmt: ShNode) {
	for (const r of stmt.Redirs ?? []) {
		const op: string = r.Op ?? "";
		let write = WRITE_REDIRS.has(op);
		if (op === ">&") {
			const lit = wordLiteral(r.Word, st.env, st.hasCd);
			write = !(lit.kind === "lit" && (/^\d+$/.test(lit.value) || lit.value === "-"));
		}
		if (!write) continue;
		const lit = wordLiteral(r.Word, st.env, st.hasCd);
		if (lit.kind === "lit" && lit.value.startsWith("/dev/")) continue;
		judgeTarget(st, "Write", resolveTarget(r.Word, st.env, st.hasCd));
	}
}

/** Generic deep walk: visit every object node. */
function walk(node: any, visit: (n: ShNode) => void) {
	if (Array.isArray(node)) {
		for (const x of node) walk(x, visit);
		return;
	}
	if (!node || typeof node !== "object") return;
	visit(node);
	for (const k of Object.keys(node)) {
		const v = node[k];
		if (v && typeof v === "object") walk(v, visit);
	}
}

/** Command name of a CallExpr after stripping wrappers (`builtin cd`, `sudo rm`), or null. */
function callName(call: ShNode, env: GuardEnv, out?: { chdir: boolean }): string | null {
	const st: WalkState = { env, hasCd: false, findings: [], resolved: [], unresolved: [], aliasExpansions: [], scripts: [], subs: [], depth: 0 };
	const argv = stripWrappers(words(call.Args, st), out);
	return cmdName(argv[0]);
}

/** True if the final top-level command is cd/pushd. */
function lastIsCd(ast: ShNode, env: GuardEnv): boolean {
	let s: ShNode | undefined = ast.Stmts?.[ast.Stmts.length - 1];
	for (let i = 0; i < 32 && s; i++) {
		const c = s.Cmd;
		if (!c) return false;
		if (c.Type === "BinaryCmd") {
			s = c.Y;
			continue;
		}
		if (c.Type === "Block" || c.Type === "Subshell") {
			if (c.Type === "Subshell") return false;
			s = c.Stmts?.[c.Stmts.length - 1];
			continue;
		}
		if (c.Type === "CallExpr") {
			const n = callName(c, env);
			return n === "cd" || n === "pushd";
		}
		return false;
	}
	return false;
}

// ---------------------------------------------------------------------------
// decide()
// ---------------------------------------------------------------------------

function emptyDecision(): Decision {
	return { verdict: "allow", findings: [], resolved: [], unresolved: [], hasCd: false, lastIsCd: false, aliasExpansions: [], scripts: [] };
}

/**
 * Deterministic verdict for a bash command (plan §4, §5). Recurses into
 * `bash -c`, `eval`, heredocs, `!`-aliases and session-written scripts with
 * the same cwd. `outerHasCd` carries a `cd` seen in the enclosing command into
 * the sub-script: `cd .. && bash -c 'rm -rf foo'` runs `rm` in the parent
 * directory, so the sub-script's relative paths are unresolvable too. Never
 * throws.
 */
export async function decide(command: string, env: GuardEnv, depth = 0, outerHasCd = false): Promise<Decision> {
	const d = emptyDecision();
	d.hasCd = outerHasCd;
	let ast: ShNode | null = null;
	try {
		ast = await env.parse(command);
	} catch (e) {
		ast = null;
		d.findings.push({ verdict: "confirm", cls: "no-shfmt", reason: `shell parser unavailable (${(e as Error)?.message ?? e}); cannot check this command` });
		d.verdict = "confirm";
		return d;
	}
	if (!ast) {
		d.findings.push({ verdict: "confirm", cls: "parse-error", reason: "command did not parse as bash; cannot check its targets" });
		d.verdict = "confirm";
		return d;
	}

	// Pre-pass: any cd anywhere (incl. `env -C DIR` / `sudo -D DIR` wrappers)
	// -> relative targets are unresolvable.
	walk(ast, (n) => {
		if (n.Type === "CallExpr") {
			const out = { chdir: false };
			const name = callName(n, env, out);
			if ((name && CD_CMDS.has(name)) || out.chdir) d.hasCd = true;
		}
	});
	d.lastIsCd = lastIsCd(ast, env);

	const st: WalkState = { env, hasCd: d.hasCd, findings: [], resolved: [], unresolved: [], aliasExpansions: [], scripts: [], subs: [], depth };
	// Statement owning each CallExpr, so heredocs/redirects are visible to it.
	const stmtOf = new WeakMap<ShNode, ShNode>();
	try {
		walk(ast, (n) => {
			if (Array.isArray(n.Redirs) && n.Redirs.length) {
				if (n.Cmd?.Type === "CallExpr") stmtOf.set(n.Cmd, n);
				handleRedirs(st, n);
			}
			if (n.Type === "CallExpr" && n.Args?.length) handleArgv(st, words(n.Args, st), stmtOf.get(n));
		});
	} catch (e) {
		st.findings.push({ verdict: "confirm", cls: "parse-error", reason: `guard internal error while analysing (${(e as Error)?.message ?? e})` });
	}

	d.findings = st.findings;
	d.resolved = st.resolved;
	d.unresolved = st.unresolved;
	d.aliasExpansions = st.aliasExpansions;
	d.scripts = st.scripts;

	if (depth < MAX_DEPTH) {
		// Sub-scripts inherit this level's cd state, not a sub-script sibling's.
		const inherit = d.hasCd;
		for (const sub of st.subs) {
			const sd = await decide(sub.script, env, depth + 1, inherit);
			for (const f of sd.findings) d.findings.push({ ...f, reason: `${f.reason} [${sub.label}]` });
			d.resolved.push(...sd.resolved);
			d.unresolved.push(...sd.unresolved);
			d.aliasExpansions.push(...sd.aliasExpansions);
			d.scripts.push(...sd.scripts);
			if (sd.hasCd) d.hasCd = true;
		}
	} else if (st.subs.length) {
		d.findings.push({ verdict: "confirm", cls: "script", reason: "nested scripts too deep to check" });
	}

	d.resolved = uniq(d.resolved);
	d.unresolved = uniq(d.unresolved);
	d.verdict = d.findings.reduce<Verdict>((v, f) => maxVerdict(v, f.verdict), "allow");
	return d;
}

/** Zone check for the `write` / `edit` tools (plan §2). */
export function decideFileWrite(path: string, env: GuardEnv): Decision {
	const d = emptyDecision();
	const v = path === "~" || path.startsWith("~/") ? env.home + path.slice(1) : path;
	const t: Target = { raw: path, path: realpathPrefix(resolveLitPath(v, env), env.fs), glob: false };
	d.resolved.push(t.path);
	const c = classifyPath(t, env);
	switch (c.kind) {
		case "allow":
			break;
		case "vcs-meta":
			d.findings.push({ verdict: "hard-block", cls: "repo-loss", target: t.path, reason: `refused: ${t.path} is inside a .git/.jj directory` });
			break;
		case "pi-meta":
			d.findings.push({ verdict: "hard-block", cls: "self-protect", target: t.path, reason: `refused: ${t.path}; writes under .pi/ are protected` });
			break;
		case "hard-root":
		case "zone-root-glob":
			d.findings.push({ verdict: "hard-block", cls: "write-root", target: t.path, reason: `refused: ${t.path} is ${describeRoot(c.root ?? t.path, env)}` });
			break;
		case "outside":
			d.findings.push({ verdict: "confirm", cls: "write-outside", target: t.path, reason: `Write ${t.path} (outside ${zoneDescription(env)})?` });
			break;
	}
	d.verdict = d.findings.reduce<Verdict>((v2, f) => maxVerdict(v2, f.verdict), "allow");
	return d;
}

// ---------------------------------------------------------------------------
// shfmt
// ---------------------------------------------------------------------------

/** Locate shfmt: $PI_GUARD_SHFMT, the nix-baked path, then PATH. */
export function findShfmt(): string | null {
	const fromEnv = process.env.PI_GUARD_SHFMT;
	if (fromEnv && existsSync(fromEnv)) return fromEnv;
	if (!SHFMT_BUILD.startsWith("@") && existsSync(SHFMT_BUILD)) return SHFMT_BUILD;
	for (const dir of (process.env.PATH ?? "").split(":")) {
		if (dir && existsSync(join(dir, "shfmt"))) return join(dir, "shfmt");
	}
	return null;
}

/** `shfmt --to-json` as a parser: null on a parse error, throws when shfmt itself fails. */
export function makeShfmtParser(bin: string): (command: string) => Promise<ShNode | null> {
	return (command) =>
		new Promise((resolveP, reject) => {
			const child = execFile(
				bin,
				["-ln", "bash", "--to-json"],
				{ timeout: SHFMT_TIMEOUT_MS, maxBuffer: 64 * 1024 * 1024, encoding: "utf8" },
				(err, stdout) => {
					if (err) {
						if ((err as any).code === 1 && !(err as any).killed) return resolveP(null); // parse error
						return reject(err);
					}
					try {
						resolveP(JSON.parse(stdout));
					} catch (e) {
						reject(e);
					}
				},
			);
			child.stdin?.on("error", () => {});
			child.stdin?.end(command);
		});
}

// ---------------------------------------------------------------------------
// Session environment
// ---------------------------------------------------------------------------

export function detectVcs(cwd: string, fs: GuardFs): { vcs: Vcs; root: string | null } {
	let dir = norm(cwd);
	for (let i = 0; i < 256; i++) {
		if (fs.exists(join(dir, ".jj"))) {
			return { vcs: fs.exists(join(dir, ".git")) ? "jj-colocated" : "jj", root: dir };
		}
		if (fs.exists(join(dir, ".git"))) return { vcs: "git", root: dir };
		const parent = dirname(dir);
		if (parent === dir) break;
		dir = parent;
	}
	return { vcs: null, root: null };
}

export function agentDir(): string {
	return process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
}

/**
 * Build the guard environment for a session cwd (plan §4.2/§4.3). Computed once
 * per session; no per-command VCS walking.
 */
export function buildEnv(
	cwd: string,
	parse: GuardEnv["parse"],
	opts: { fs?: GuardFs; home?: string; tmpdir?: string; guardDir?: string } = {},
): GuardEnv {
	const fs = opts.fs ?? realFs;
	const real = (p: string) => norm(fs.exists(p) ? fs.realpath(p) : p);
	const home = real(opts.home ?? homedir());
	const tmp = real(opts.tmpdir ?? process.env.TMPDIR ?? tmpdir());
	const cwdR = real(cwd);
	const { vcs, root } = detectVcs(cwdR, fs);
	const projectMode = root !== null && root !== home && !isInside(home, root);
	const zone = uniq([...(projectMode ? [cwdR] : []), "/tmp", "/var/tmp", tmp, join(home, ".cache")].map(real));
	return {
		cwd: cwdR,
		home,
		tmpdir: tmp,
		zone,
		projectMode,
		vcs,
		gitAliases: {},
		jjAliases: {},
		fs,
		parse,
		sessionScripts: new Map(),
		guardDir: norm(opts.guardDir ?? join(agentDir(), "jev-guard")),
	};
}

function run(cmd: string, args: string[], cwd: string): Promise<string> {
	return new Promise((resolveP) => {
		execFile(cmd, args, { cwd, timeout: 5000, encoding: "utf8" }, (err, stdout) => resolveP(err ? "" : stdout));
	});
}

export function parseGitAliases(out: string): Record<string, string> {
	const r: Record<string, string> = {};
	for (const line of out.split("\n")) {
		const m = /^alias\.(\S+) (.*)$/.exec(line);
		if (m) r[m[1]] = m[2];
	}
	return r;
}

export function parseJjAliases(out: string): Record<string, string[]> {
	const r: Record<string, string[]> = {};
	for (const line of out.split("\n")) {
		const m = /^aliases\.("(?:[^"\\]|\\.)*"|[^\s=]+)\s*=\s*(.*)$/.exec(line);
		if (!m) continue;
		const name = m[1].startsWith('"') ? m[1].slice(1, -1) : m[1];
		try {
			const v = JSON.parse(m[2]);
			if (Array.isArray(v) && v.every((x) => typeof x === "string")) r[name] = v;
			else if (typeof v === "string") r[name] = v.split(/\s+/).filter(Boolean);
		} catch {
			// TOML that isn't JSON-compatible: treat the alias as opaque -> no expansion.
		}
	}
	return r;
}

/** Load the user's git and jj aliases (plan §3). */
async function loadAliases(cwd: string): Promise<{ git: Record<string, string>; jj: Record<string, string[]> }> {
	const [g, j] = await Promise.all([
		run("git", ["config", "--get-regexp", "^alias\\."], cwd),
		run("jj", ["--ignore-working-copy", "--color=never", "--no-pager", "config", "list", "aliases"], cwd),
	]);
	return { git: parseGitAliases(g), jj: parseJjAliases(j) };
}

// ---------------------------------------------------------------------------
// jev (TypeSafe classifier)
// ---------------------------------------------------------------------------

export const JEV_QUESTIONS = {
	publishes: {
		type: "bool" as const,
		instructions:
			"Does `command` (see `alias_expansion` for user aliases) publish commits, bookmarks, branches, tags, pull requests, releases or packages to any remote repository or registry?",
		criteria: {
			true: "It pushes, uploads, publishes, merges or releases something to a remote or registry",
			false: "Everything it does stays on the local machine",
		},
	},
	writes_outside: {
		type: "bool" as const,
		instructions:
			// The trailing `cd` sentence is measured (redteam/jev-experiment/RESULTS.md, variant V5):
			// it lifts padded `cd .. && bash -c 'rm -rf <cwd basename> && echo …'` from ~0.45 to ~0.6–0.7
			// with no false positives. Extra state fields (cwd_basename, effective cwd) or a dedicated
			// question did NOT help and caused false positives; don't add them.
			"Does `command` delete, move, truncate or overwrite files or directories outside every directory listed in `zone`, or delete a `zone` root or `cwd` itself? Temp and cache directories listed in `zone` count as inside. Consider scripts in `script`, which the command executes. Pay attention to `cd`: a relative path after `cd X` resolves against X, not `cwd`. `cd .. && rm -rf <basename of cwd>` deletes cwd itself.",
		criteria: {
			true: "It writes or deletes outside `zone`, or removes a zone root / the cwd itself",
			false: "All writes and deletes stay strictly inside the `zone` directories, or it only reads",
		},
	},
	repo_loss: {
		type: "bool" as const,
		instructions:
			"Does `command` cause UNRECOVERABLE loss of version-control state? jj's operation log makes ordinary jj operations (abandon, undo, rebase, squash, op restore, bookmark delete) recoverable. Only deleting .git/.jj metadata, gc/prune of unreachable objects, reflog expiry, `jj op abandon` and similar count.",
		criteria: {
			true: "Version-control history or metadata would be destroyed beyond recovery",
			false: "Any effect on the repository is recoverable or there is none",
		},
	},
	other_irreversible: {
		type: "bool" as const,
		instructions:
			"Apart from the cases above, does `command` destroy data, infrastructure or external state (databases, cloud resources, containers/volumes, remote APIs with DELETE semantics, other users' files, system configuration) in a way the user would want to confirm first?",
		criteria: {
			true: "It irreversibly destroys or alters data, infrastructure or external state",
			false: "It is read-only, reversible, or only affects local scratch files",
		},
	},
};

export type JevResult =
	| { status: "ok"; probs: Record<string, number>; ms: number; usage?: unknown }
	| { status: "no-auth" | "down" | "skipped" | "disabled"; ms: number; error?: string };

/** Which jev questions are at/above the confirm threshold. */
export function jevFlags(probs: Record<string, number>): string[] {
	return Object.entries(probs)
		.filter(([, p]) => p >= JEV_CONFIRM_P)
		.sort((a, b) => b[1] - a[1])
		.map(([k]) => k);
}

// ---------------------------------------------------------------------------
// Extension wiring
// ---------------------------------------------------------------------------

type Mode = "on" | "log" | "off";

function readMode(): Mode {
	const v = (process.env.PI_GUARD ?? "").trim().toLowerCase();
	if (v === "off" || v === "0" || v === "false") return "off";
	if (v === "log") return "log";
	return "on";
}

function truncate(s: string, n: number): string {
	const one = s.replace(/\s+/g, " ").trim();
	return one.length > n ? `${one.slice(0, n - 1)}…` : one;
}

/** Reasons are phrased as questions for the dialog; as statements elsewhere. */
function asStatement(reason: string): string {
	return reason.replace(/\s*Continue\?$/, "").replace(/\?$/, "");
}

function topReasons(findings: Finding[], verdict: Verdict, max = 3): string[] {
	const top = uniq(findings.filter((f) => f.verdict === verdict).map((f) => asStatement(f.reason)));
	const out = top.slice(0, max);
	if (top.length > max) out.push(`…and ${top.length - max} more`);
	return out;
}

export default function (pi: ExtensionAPI) {
	const S = {
		mode: readMode() as Mode,
		env: null as GuardEnv | null,
		shfmt: null as string | null,
		jev: "unknown" as "ok" | "no-auth" | "down" | "disabled" | "unknown",
		counts: { allow: 0, confirm: 0, block: 0 },
		breaker: { failures: 0, openUntil: 0 },
		cdNotes: new Map<string, string>(),
		logDir: join(agentDir(), "jev-guard"),
		logChecked: false,
	};

	// ---- logging -----------------------------------------------------------
	function log(entry: Record<string, unknown>) {
		try {
			const file = join(S.logDir, "decisions.jsonl");
			if (!S.logChecked) {
				mkdirSync(S.logDir, { recursive: true });
				S.logChecked = true;
			}
			try {
				if (statSync(file).size > LOG_MAX_BYTES) renameSync(file, `${file}.1`);
			} catch {
				// no file yet
			}
			appendFileSync(file, `${JSON.stringify({ ts: new Date().toISOString(), ...entry })}\n`);
		} catch {
			// logging must never break the guard
		}
	}

	// ---- footer ------------------------------------------------------------
	function status(ctx: ExtensionContext) {
		if (S.mode === "off") {
			ctx.ui.setStatus(STATUS_KEY, undefined);
			return;
		}
		const c = S.counts;
		const parts = [`guard ✓${c.allow} ?${c.confirm} ✗${c.block}`];
		if (S.mode === "log") parts.push("LOG ONLY");
		if (S.env && !S.env.projectMode) parts.push("no project — writes outside temp confirm");
		if (!S.shfmt) parts.push("NO shfmt");
		if (S.jev === "no-auth") parts.push("NO JEV — /login typesafe");
		else if (S.jev === "down") parts.push("jev DOWN");
		else if (S.jev === "disabled") parts.push("jev off");
		ctx.ui.setStatus(STATUS_KEY, parts.join(" · "));
	}

	// ---- jev ---------------------------------------------------------------
	function jevModel(ctx: ExtensionContext) {
		try {
			const reg: any = ctx.modelRegistry;
			const m = reg?.findOfType?.("classifier", "typesafe", "jev-latest");
			if (!m) return null;
			if (typeof reg.hasConfiguredAuth === "function" && !reg.hasConfiguredAuth(m)) return null;
			return m;
		} catch {
			return null;
		}
	}

	async function askJev(ctx: ExtensionContext, state: Record<string, unknown>): Promise<JevResult> {
		const t0 = performance.now();
		if (JEV_BUILD === "false" || process.env.PI_GUARD_JEV === "0") {
			S.jev = "disabled";
			return { status: "disabled", ms: 0 };
		}
		const model = jevModel(ctx);
		if (!model) {
			S.jev = "no-auth";
			return { status: "no-auth", ms: 0 };
		}
		if (Date.now() < S.breaker.openUntil) return { status: "skipped", ms: 0, error: "circuit open" };
		try {
			const timeout = new Promise<null>((r) => setTimeout(() => r(null), JEV_TIMEOUT_MS + 250).unref?.());
			const r: any = await Promise.race([
				ctx.modelRegistry.classify(model, { state: state as any, questions: JEV_QUESTIONS }, {
					timeoutMs: JEV_TIMEOUT_MS,
					maxRetries: 1,
					maxRetryDelayMs: 0,
					signal: ctx.signal,
				} as any),
				timeout,
			]);
			const ms = Math.round(performance.now() - t0);
			if (!r || r.stopReason !== "stop") {
				S.breaker.failures++;
				if (S.breaker.failures >= JEV_BREAKER_FAILURES) S.breaker.openUntil = Date.now() + JEV_BREAKER_COOLDOWN_MS;
				S.jev = "down";
				return { status: "down", ms, error: r ? `${r.stopReason}: ${r.errorMessage ?? ""}` : "timeout" };
			}
			const probs: Record<string, number> = {};
			for (const [k, a] of Object.entries<any>(r.answers ?? {})) {
				if (a?.type === "bool" && typeof a.probability === "number") probs[k] = a.probability;
			}
			S.breaker.failures = 0;
			S.jev = "ok";
			return { status: "ok", probs, ms, usage: r.usage };
		} catch (e) {
			S.breaker.failures++;
			if (S.breaker.failures >= JEV_BREAKER_FAILURES) S.breaker.openUntil = Date.now() + JEV_BREAKER_COOLDOWN_MS;
			S.jev = "down";
			return { status: "down", ms: Math.round(performance.now() - t0), error: String((e as Error)?.message ?? e) };
		}
	}

	// ---- helpers -----------------------------------------------------------
	function ensureEnv(ctx: ExtensionContext): GuardEnv {
		if (S.env && S.env.cwd === norm(realFs.realpath(ctx.cwd))) return S.env;
		S.shfmt = findShfmt();
		const parse = S.shfmt
			? makeShfmtParser(S.shfmt)
			: async () => {
					throw new Error("shfmt not found");
				};
		S.env = buildEnv(ctx.cwd, parse);
		return S.env;
	}

	async function snapshot(env: GuardEnv) {
		if (!env.vcs?.startsWith("jj") || process.env.PI_GUARD_SNAPSHOT === "0") return;
		await run("jj", ["--color=never", "--no-pager", "debug", "snapshot"], env.cwd);
	}

	function confirmTitle(kind: string, reasons: string[], env: GuardEnv, command: string, jev?: JevResult): string {
		const lines = [`jev-guard: ${reasons[0]}`];
		for (const r of reasons.slice(1)) lines.push(`  + ${r}`);
		if (jev?.status === "ok") {
			const flags = jevFlags(jev.probs);
			if (flags.length) lines.push(`  jev: ${flags.map((f) => `${f} p=${jev.probs[f].toFixed(2)}`).join(", ")}`);
		}
		lines.push(`cwd: ${env.cwd}${env.projectMode ? "" : " (no project)"}`);
		lines.push(`${kind}: ${truncate(command, MAX_TITLE_CMD)}`);
		lines.push("Continue?");
		return lines.join("\n");
	}

	/** Common tail: UI confirm / headless block. Returns a tool_call result or undefined (allow). */
	async function gate(
		ctx: ExtensionContext,
		env: GuardEnv,
		verdict: Verdict,
		reasons: string[],
		kind: string,
		summary: string,
		logEntry: Record<string, unknown>,
		jev?: JevResult,
	) {
		const reasonText = reasons.join("; ");
		if (verdict === "hard-block") {
			S.counts.block++;
			log({ ...logEntry, final: "hard-block" });
			status(ctx);
			if (S.mode === "log") return undefined;
			return { block: true, reason: `jev-guard ${reasonText} (cwd: ${env.cwd}). This is a hard rule; if it is really needed, ask the user to run it themselves.` };
		}
		if (verdict === "confirm") {
			if (S.mode === "log") {
				S.counts.confirm++;
				log({ ...logEntry, final: "confirm", user: "log-only" });
				status(ctx);
				return undefined;
			}
			if (!ctx.hasUI) {
				S.counts.block++;
				log({ ...logEntry, final: "block", user: "headless" });
				status(ctx);
				return { block: true, reason: `jev-guard: blocked by policy (no UI to confirm): ${reasonText}. Ask the user to run this themselves or confirm it in an interactive session.`, terminate: true };
			}
			const t0 = performance.now();
			const choice = await ctx.ui.select(confirmTitle(kind, reasons, env, summary, jev), ["No", "Yes"], { timeout: CONFIRM_TIMEOUT_MS, signal: ctx.signal });
			const waitMs = Math.round(performance.now() - t0);
			// select() returns undefined for both the countdown expiring and Esc/abort.
			const timedOut = waitMs >= CONFIRM_TIMEOUT_MS - 2000;
			if (choice === "Yes") {
				S.counts.confirm++;
				log({ ...logEntry, final: "allow", user: "yes", wait_ms: waitMs });
				status(ctx);
				await snapshot(env);
				return undefined;
			}
			S.counts.block++;
			status(ctx);
			if (choice === undefined) {
				log({ ...logEntry, final: "block", user: timedOut ? "timeout" : "cancelled", wait_ms: waitMs });
				return { block: true, reason: `jev-guard: confirmation ${timedOut ? "timed out" : "was cancelled"}: ${reasonText}. Stop and ask the user.`, terminate: true };
			}
			log({ ...logEntry, final: "block", user: "no", wait_ms: waitMs });
			return { block: true, reason: `jev-guard: the user declined: ${reasonText}. Do not retry without asking the user.` };
		}
		S.counts.allow++;
		log({ ...logEntry, final: "allow" });
		status(ctx);
		return undefined;
	}

	// ---- lifecycle ---------------------------------------------------------
	pi.on("session_start", async (_event, ctx) => {
		S.mode = readMode();
		S.env = null;
		S.counts = { allow: 0, confirm: 0, block: 0 };
		S.cdNotes.clear();
		if (S.mode === "off") {
			status(ctx);
			return;
		}
		const env = ensureEnv(ctx);
		if (JEV_BUILD === "false" || process.env.PI_GUARD_JEV === "0") S.jev = "disabled";
		else S.jev = jevModel(ctx) ? "ok" : "no-auth";
		status(ctx);
		log({ event: "session_start", mode: S.mode, cwd: env.cwd, zone: env.zone, project_mode: env.projectMode, vcs: env.vcs, shfmt: S.shfmt, jev: S.jev });
		try {
			const a = await loadAliases(env.cwd);
			env.gitAliases = a.git;
			env.jjAliases = a.jj;
		} catch {
			// no git/jj: no aliases
		}
	});

	pi.on("session_shutdown", (_event, ctx) => {
		ctx.ui.setStatus(STATUS_KEY, undefined);
		S.cdNotes.clear();
	});

	pi.on("tool_call", async (event, ctx) => {
		if (S.mode === "off") return undefined;

		// ---- write / edit: zone check only ----
		if (event.toolName === "write" || event.toolName === "edit") {
			const env = ensureEnv(ctx);
			const path = String((event.input as any)?.path ?? "");
			if (!path) return undefined;
			const d = decideFileWrite(path, env);
			// Track session-written scripts (incl. pending writes earlier in this batch).
			const abs = d.resolved[0] ?? path;
			if (event.toolName === "write") env.sessionScripts.set(abs, String((event.input as any)?.content ?? ""));
			else if (!env.sessionScripts.has(abs)) env.sessionScripts.set(abs, null);
			const reasons = d.verdict === "allow" ? [] : topReasons(d.findings, d.verdict);
			return gate(ctx, env, d.verdict, reasons, event.toolName, path, {
				tool: event.toolName,
				path,
				cwd: env.cwd,
				resolved: d.resolved,
				det: d.verdict,
				findings: d.findings.map((f) => ({ v: f.verdict, c: f.cls, r: f.reason })),
			});
		}

		if (event.toolName !== "bash") return undefined;
		const env = ensureEnv(ctx);
		const command = String((event.input as any)?.command ?? "");
		const t0 = performance.now();
		const det = await decide(command, env);
		const detMs = Math.round(performance.now() - t0);

		const state: Record<string, unknown> = {
			command,
			alias_expansion: det.aliasExpansions.join("; ") || null,
			cwd: env.cwd,
			zone: env.zone,
			project_mode: env.projectMode,
			vcs: env.vcs,
			resolved_targets: det.resolved,
			unresolved_targets: det.unresolved,
			...(det.scripts.length ? { script: det.scripts.join("\n---\n").slice(0, 16_000) } : {}),
		};
		const jev = await askJev(ctx, state);

		// final = max(det, jev); jev only raises allow -> confirm.
		let final = det.verdict;
		const findings = [...det.findings];
		if (jev.status === "ok") {
			const flags = jevFlags(jev.probs);
			if (flags.length) {
				final = maxVerdict(final, "confirm");
				findings.push({ verdict: "confirm", cls: "jev", reason: `jev thinks this ${flags.map((f) => `${f.replace(/_/g, " ")} (p=${jev.probs[f].toFixed(2)})`).join(", ")}` });
			}
		}
		const reasons = final === "allow" ? [] : topReasons(findings, final);

		const logEntry = {
			tool: "bash",
			cmd: command,
			cwd: env.cwd,
			zone: env.zone,
			project_mode: env.projectMode,
			vcs: env.vcs,
			resolved: det.resolved,
			unresolved: det.unresolved,
			alias: det.aliasExpansions,
			has_cd: det.hasCd,
			det: det.verdict,
			findings: det.findings.map((f) => ({ v: f.verdict, c: f.cls, r: f.reason })),
			jev: jev.status === "ok" ? jev.probs : { status: jev.status, error: (jev as any).error },
			det_ms: detMs,
			jev_ms: jev.ms,
			mode: S.mode,
			parent: event.parentToolCallId ?? null,
		};
		const result = await gate(ctx, env, final, reasons, "$", command, logEntry, jev);
		// Any cd in the call (not just a trailing one): `cd /tmp/x && git init && pwd`
		// prints the temp dir and is exactly what convinces the model it moved.
		if (!result && det.hasCd) {
			S.cdNotes.set(event.toolCallId, `note: cwd does not persist between bash calls; the next call starts in ${env.cwd}`);
		}
		return result;
	});

	// Stale-cd note (plan §4.4).
	pi.on("tool_result", (event) => {
		if (event.toolName !== "bash") return undefined;
		const note = S.cdNotes.get(event.toolCallId);
		if (!note) return undefined;
		S.cdNotes.delete(event.toolCallId);
		const content = [...(event.content ?? [])];
		const last = content.length - 1;
		if (last >= 0 && content[last].type === "text") {
			const t = (content[last] as any).text ?? "";
			content[last] = { ...(content[last] as any), text: `${t}${t.endsWith("\n") || t === "" ? "" : "\n"}${note}` };
		} else {
			content.push({ type: "text", text: note });
		}
		return { content, structuredContent: event.structuredContent };
	});
}

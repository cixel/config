/**
 * pi-fence — OS-level write fence for pi's `bash` tool.
 *
 * jev-guard (a `tool_call` policy hook) can only gate what it can parse:
 * heredocs, `bash -c` nesting, session-written scripts and `make` have
 * bypass shapes. The fence is the layer underneath: every bash tool call is
 * executed inside an OS sandbox — sandbox-exec on macOS, bubblewrap on
 * Linux — whose writable set is exactly the session *zone*:
 *
 *   repo root of the session cwd  (+ /tmp, /var/tmp, $TMPDIR,
 *                                  ~/.cache, ~/.local/state/nix)
 *
 * Everything else under `/` is read-only for the call. Reads and network
 * are untouched: agents still inspect the whole machine and fetch freely;
 * `git push` stays a jev-guard policy decision. User `!` commands do not
 * go through the bash tool and are never fenced.
 *
 * Scope notes (see agents/pi/pi-fence.md):
 *   - `write`/`edit` are NOT fenced: their target path is exact and already
 *     zone-checked by jev-guard with no parser in between.
 *   - pi must be started inside a jj/git repo whose root is not $HOME or an
 *     ancestor of it; otherwise the bash tool is disabled for the session
 *     ("blocked"). If the sandbox itself fails a launch-time probe the tool
 *     is likewise disabled ("down"): fail closed, no overrides.
 *   - The zone is computed once at session_start; it does not follow a
 *     mid-session cwd change (jev-guard behaves the same).
 *   - The fence is a filesystem boundary, not a process boundary: fenced
 *     commands share the host PID/network namespaces and can signal
 *     same-uid processes. Accident containment, not adversarial containment
 *     (that is gondolin's job; the two are not meant to be co-installed).
 *
 * The generated sandbox profile and session shell live under
 * ~/.pi/agent/pi-fence/ — outside the zone, so fenced commands cannot
 * rewrite their own boundary (and jev-guard hard-blocks ~/.pi writes).
 *
 * Pure logic (zone computation, profile/argv generation, probing) is
 * exported and takes a `FenceHost` so the bun tests never touch the real
 * system; only the default export wires it into pi. Run the hardware suite
 * (tests/pi-fence-hardware.mjs) to verify the real kernel boundary.
 */

import { spawnSync } from "node:child_process";
import {
	appendFileSync,
	chmodSync,
	existsSync,
	mkdirSync,
	readdirSync,
	realpathSync,
	statSync,
	unlinkSync,
	writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import {
	createBashTool,
	createLocalBashOperations,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "fence";
/** macOS system binary; not in the nix store, but at a stable absolute path. */
const SANDBOX_EXEC = "/usr/bin/sandbox-exec";
/** Nix-baked tool paths (mkPiPluginFromFile substitutions; see pi.nix). */
const BASH = "@bash@";
const BWRAP = "@bwrap@";
const GC_MAX_AGE_MS = 24 * 60 * 60 * 1000;
const RUN_TIMEOUT_MS = 15_000;

// ---------------------------------------------------------------------------
// Host abstraction (all side effects go through this; tests fake it)
// ---------------------------------------------------------------------------

export interface FenceHost {
	exists(p: string): boolean;
	/** Canonical absolute path; throws if `p` does not exist. */
	realpath(p: string): string;
	mkdirp(p: string): void;
	writeFile(p: string, content: string, mode: number): void;
	remove(p: string): void;
	/** Run argv with stdout captured; never throws on non-zero exit. */
	run(argv: string[], opts: { cwd?: string }): { status: number; stdout: string };
	/** Append one line to a log file, creating parent dirs. */
	append(p: string, line: string): void;
	/** Delete stale generated files (shell-N / profile-N.sb) older than maxAgeMs. */
	gc(dir: string, maxAgeMs: number): void;
}

export interface FenceEnv {
	platform: string;
	pid: number;
	home: string;
	tmpdir: string;
	agentDir: string;
	bash: string;
	bwrap: string;
}

export function realHost(): FenceHost {
	return {
		exists: (p) => existsSync(p),
		realpath: (p) => realpathSync(p),
		mkdirp: (p) => mkdirSync(p, { recursive: true }),
		writeFile: (p, content, mode) => {
			writeFileSync(p, content);
			chmodSync(p, mode);
		},
		remove: (p) => {
			try {
				unlinkSync(p);
			} catch {
				// absent or already gone
			}
		},
		run: (argv, opts) => {
			const r = spawnSync(argv[0], argv.slice(1), {
				cwd: opts.cwd,
				encoding: "utf8",
				stdio: ["ignore", "pipe", "pipe"],
				timeout: RUN_TIMEOUT_MS,
			});
			return { status: r.status ?? 1, stdout: r.stdout ?? "" };
		},
		append: (p, line) => {
			mkdirSync(dirname(p), { recursive: true });
			appendFileSync(p, line);
		},
		gc: (dir, maxAgeMs) => {
			const cutoff = Date.now() - maxAgeMs;
			for (const name of readdirSync(dir)) {
				if (!/^(shell|profile)-\d+(\.sb)?$/.test(name)) continue;
				const p = join(dir, name);
				try {
					if (statSync(p).mtimeMs < cutoff) unlinkSync(p);
				} catch {
					// race with another session: fine
				}
			}
		},
	};
}

export function defaultEnv(): FenceEnv {
	return {
		platform: process.platform,
		pid: process.pid,
		home: homedir(),
		tmpdir: process.env.TMPDIR ?? tmpdir(),
		agentDir: process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent"),
		bash: BASH,
		bwrap: BWRAP,
	};
}

// ---------------------------------------------------------------------------
// Pure logic
// ---------------------------------------------------------------------------

/** `p` is strictly inside directory `ancestor` (both absolute). */
export function isStrictlyInside(p: string, ancestor: string): boolean {
	const norm = (v: string) => (v === "/" ? "/" : v.replace(/\/+$/, ""));
	const pp = norm(p);
	const a = norm(ancestor);
	if (pp === a) return false;
	return a === "/" ? pp.startsWith("/") : pp.startsWith(`${a}/`);
}

export function shQuote(v: string): string {
	return `'${v.replace(/'/g, `'\\''`)}'`;
}

/** Escape a path for an SBPL string literal. */
function sbEscape(v: string): string {
	return v.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

/**
 * Why a session at this repo root can never be fenced safely: the zone
 * would swallow $HOME (or everything), making the fence meaningless.
 */
export function refusedRoot(root: string, home: string): string | null {
	if (root === home) {
		return `repository root IS your home directory (${root}); refusing to fence a session that wide — move the repo (a dotfiles repo at ~ does not count) or work inside a subdirectory repo`;
	}
	if (isStrictlyInside(home, root)) {
		return `repository root ${root} is an ancestor of your home directory; refusing to fence a session that wide`;
	}
	return null;
}

/** jj first (the user's primary VCS), git second (covers plain-git repos). */
export function findRepoRoot(cwd: string, host: FenceHost): string | null {
	for (const argv of [
		["jj", "root"],
		["git", "rev-parse", "--show-toplevel"],
	]) {
		const r = host.run(argv, { cwd });
		if (r.status !== 0) continue;
		const out = r.stdout.trim();
		if (!out.startsWith("/")) continue;
		try {
			return host.realpath(out);
		} catch {
			// implausible answer; try the next VCS
		}
	}
	return null;
}

/**
 * The writable set. Realpath'd (macOS: /tmp -> /private/tmp, $TMPDIR ->
 * /private/var/folders/...), deduped, nested entries dropped (an ancestor
 * bind/allow already covers them). `~/.local/state/nix` is required so
 * plain `nix build` can register indirect gcroots; profile/generation
 * mutations (hms, nix profile) stay fenced out — agents never run those.
 */
export function computeZone(
	paths: { root: string; home: string; tmpdir: string },
	host: Pick<FenceHost, "exists" | "realpath">,
): string[] {
	const candidates = [
		paths.root,
		"/tmp",
		"/var/tmp",
		paths.tmpdir,
		join(paths.home, ".cache"),
		join(paths.home, ".local/state/nix"),
	];
	const out: string[] = [];
	for (const c of candidates) {
		let r: string;
		try {
			r = host.realpath(c);
		} catch {
			if (c === paths.root) throw new Error(`repo root ${c} does not exist`);
			continue; // absent optional dir: skip
		}
		if (!out.includes(r)) out.push(r);
	}
	return out.filter((z) => !out.some((o) => o !== z && isStrictlyInside(z, o)));
}

/**
 * Seatbelt profile: default-allow with a global write deny and more
 * specific allows on top. SBPL resolves conflicting rules by filter
 * specificity (the longer subpath wins), so the zone allows override the
 * `/` deny. `/dev` stays writable (/dev/null is how everything logs), as
 * does the nix daemon socket (unix-connect is gated by file-write*).
 * Verified on real hardware by tests/pi-fence-hardware.mjs.
 */
export function seatbeltProfile(zone: string[]): string {
	const allows = zone.map((z) => `\t(subpath "${sbEscape(z)}")`).join("\n");
	return `;; pi-fence: generated per session; do not edit (regenerated at launch)
(version 1)
(allow default)
(deny file-write* (subpath "/"))
(allow file-write*
${allows}
\t(subpath "/dev")
\t(subpath "/nix/var/nix/daemon-socket"))
`;
}

/**
 * bubblewrap argv: host mounted read-only, device nodes re-bound writable
 * (writes to /dev/null and friends are device I/O, not filesystem writes),
 * then the zone bind-mounted writable on top. Network and PID namespaces
 * are shared with the host: agents need to fetch, and backgrounded
 * processes (`npm run dev &`) must survive the end of a bash call.
 * --die-with-parent keeps a crashed pi from leaking fenced strays.
 */
export function bwrapArgs(zone: string[]): string[] {
	const args = ["--ro-bind", "/", "/", "--dev-bind", "/dev", "/dev", "--die-with-parent"];
	for (const z of zone) args.push("--bind", z, z);
	return args;
}

/**
 * The session shell: what pi's bash tool is given as its "shell". It
 * receives `-c <command>` and re-execs it inside the sandbox. The profile
 * is baked into the script on Linux; on macOS it lives in profilePath.
 */
export function sessionScript(opts: {
	platform: string;
	zone: string[];
	bash: string;
	bwrap: string;
	profilePath: string;
}): string {
	const header = "#!/bin/sh\n# Generated by pi-fence at session start; do not edit.\n";
	if (opts.platform === "darwin") {
		return `${header}exec ${shQuote(SANDBOX_EXEC)} -f ${shQuote(opts.profilePath)} ${shQuote(opts.bash)} "$@"\n`;
	}
	const args = bwrapArgs(opts.zone).map(shQuote).join(" ");
	return `${header}exec ${shQuote(opts.bwrap)} ${args} ${shQuote(opts.bash)} "$@"\n`;
}

export interface ProbeResult {
	ok: boolean;
	detail: string;
}

/**
 * Fail-closed launch probe: the session shell must (a) run at all,
 * (b) allow writes inside the zone, and (c) deny a write to $HOME. If the
 * sandbox mechanism is broken (sandbox-exec removed, userns disabled,
 * profile semantics changed under us) the session goes "down" and the
 * bash tool refuses to run — no silent unfenced sessions.
 */
export function probeFence(shellPath: string, root: string, home: string, host: FenceHost): ProbeResult {
	const tag = `.pi-fence-probe-${basename(shellPath)}`;
	const run = (cmd: string, cwd: string) => host.run([shellPath, "-c", cmd], { cwd });

	let r = run("true", root);
	if (r.status !== 0) return { ok: false, detail: `sandbox shell failed to run a trivial command (exit ${r.status})` };

	r = run("echo ok > /dev/null", root);
	if (r.status !== 0) return { ok: false, detail: "/dev/null is not writable inside the sandbox" };

	r = run(`d=${shQuote(tag)} && mkdir "$d" && rmdir "$d"`, root);
	if (r.status !== 0) return { ok: false, detail: `cannot write inside the zone (${root}) — the fence would break every command` };

	const cacheProbe = join(home, ".cache", tag);
	r = run(`touch ${shQuote(cacheProbe)} && rm ${shQuote(cacheProbe)}`, root);
	if (r.status !== 0) return { ok: false, detail: `cannot write to ~/.cache — a zone root` };

	const outside = join(home, tag);
	r = run(`touch ${shQuote(outside)}`, home);
	if (r.status === 0) {
		host.remove(outside);
		return { ok: false, detail: `write to $HOME succeeded — the sandbox is NOT enforcing; refusing to run unfenced` };
	}
	return { ok: true, detail: "ok" };
}

// ---------------------------------------------------------------------------
// Session initialisation
// ---------------------------------------------------------------------------

export type FenceMode = "pending" | "active" | "blocked" | "down";

export interface FenceState {
	mode: FenceMode;
	/** Human-readable explanation for blocked/down. */
	reason: string;
	root: string | null;
	zone: string[];
	scriptPath: string | null;
	profilePath: string | null;
}

export function initFence(cwd: string, env: FenceEnv, host: FenceHost): FenceState {
	const state = (mode: FenceMode, reason: string): FenceState => ({
		mode,
		reason,
		root: null,
		zone: [],
		scriptPath: null,
		profilePath: null,
	});

	const root = findRepoRoot(cwd, host);
	if (!root) {
		return state("blocked", `not inside a jj/git repository (cwd: ${cwd}) — cd into a repo and restart pi`);
	}
	const refusal = refusedRoot(root, env.home);
	if (refusal) return state("blocked", refusal);

	let zone: string[];
	try {
		zone = computeZone({ root, home: env.home, tmpdir: env.tmpdir }, host);
	} catch (e) {
		return state("down", `zone computation failed: ${e instanceof Error ? e.message : String(e)}`);
	}

	// bwrap bind sources must exist; harmless mkdir on macOS.
	for (const p of [join(env.home, ".cache"), join(env.home, ".local/state/nix")]) {
		try {
			host.mkdirp(p);
		} catch {
			// the probe below catches a genuinely unwritable home
		}
	}

	const dir = join(env.agentDir, "pi-fence");
	const scriptPath = join(dir, `shell-${env.pid}`);
	const profilePath = join(dir, `profile-${env.pid}.sb`);
	try {
		host.mkdirp(dir);
		if (env.platform === "darwin") host.writeFile(profilePath, seatbeltProfile(zone), 0o600);
		host.writeFile(scriptPath, sessionScript({ platform: env.platform, zone, bash: env.bash, bwrap: env.bwrap, profilePath }), 0o700);
	} catch (e) {
		return state("down", `cannot write sandbox profile under ${dir}: ${e instanceof Error ? e.message : String(e)}`);
	}
	try {
		host.gc(dir, GC_MAX_AGE_MS);
	} catch {
		// housekeeping never fails a session
	}

	const probe = probeFence(scriptPath, root, env.home, host);
	if (!probe.ok) {
		host.remove(scriptPath);
		host.remove(profilePath);
		return state("down", `sandbox probe failed: ${probe.detail}`);
	}
	return {
		mode: "active",
		reason: "",
		root,
		zone,
		scriptPath,
		profilePath: env.platform === "darwin" ? profilePath : null,
	};
}

// ---------------------------------------------------------------------------
// pi wiring
// ---------------------------------------------------------------------------

/** Pi's tool factories, injectable so tests never load the real package. */
export interface FenceToolFactories {
	createBashTool: (cwd: string, options?: { operations?: unknown }) => {
		execute: (...args: unknown[]) => unknown;
	} & Record<string, unknown>;
	createLocalBashOperations: (options?: { shellPath?: string }) => unknown;
}

export function wireFence(pi: ExtensionAPI, factories: FenceToolFactories, env: FenceEnv, host: FenceHost): void {
	const loadCwd = process.cwd();
	const S = {
		state: {
			mode: "pending",
			reason: "session has not started",
			root: null,
			zone: [],
			scriptPath: null,
			profilePath: null,
		} as FenceState,
		tool: null as ({ execute: (...args: unknown[]) => unknown } & Record<string, unknown>) | null,
		logFile: join(env.agentDir, "pi-fence", "sessions.jsonl"),
	};

	function log(entry: Record<string, unknown>) {
		try {
			host.append(S.logFile, `${JSON.stringify({ ts: new Date().toISOString(), ...entry })}\n`);
		} catch {
			// logging must never break the fence
		}
	}

	function status(ctx: ExtensionContext) {
		const s = S.state;
		if (s.mode === "active") ctx.ui.setStatus(STATUS_KEY, `fence ✓ ${basename(s.root ?? "")}`);
		else if (s.mode === "pending") ctx.ui.setStatus(STATUS_KEY, "fence …");
		else ctx.ui.setStatus(STATUS_KEY, `fence ✗ ${s.mode.toUpperCase()}`);
	}

	function ensure(ctx: ExtensionContext | undefined): FenceState {
		if (S.state.mode === "pending") S.state = initFence(ctx?.cwd ?? loadCwd, env, host);
		return S.state;
	}

	// Override the built-in bash tool: same definition, but exec routes
	// through the session shell. pi's own spawn/timeout/kill-tree logic
	// (createLocalBashOperations) is reused untouched — the only difference
	// from a stock session is which "shell" the command lands in.
	pi.registerTool({
		...factories.createBashTool(loadCwd),
		async execute(id: string, params: unknown, signal: AbortSignal | undefined, onUpdate: unknown, ctx?: ExtensionContext) {
			const s = ensure(ctx);
			if (s.mode !== "active") {
				throw new Error(`pi-fence: refusing to run bash unfenced — ${s.reason}`);
			}
			if (!S.tool) {
				S.tool = factories.createBashTool(loadCwd, {
					operations: factories.createLocalBashOperations({ shellPath: s.scriptPath! }),
				});
			}
			return S.tool.execute(id, params, signal, onUpdate);
		},
	} as never);

	pi.on("session_start", (_event, ctx) => {
		S.state = initFence(ctx.cwd, env, host);
		S.tool = null;
		status(ctx);
		log({
			event: "session_start",
			mode: S.state.mode,
			cwd: ctx.cwd,
			root: S.state.root,
			zone: S.state.zone,
			reason: S.state.reason || undefined,
		});
		if (S.state.mode === "blocked" || S.state.mode === "down") {
			if (ctx.hasUI) ctx.ui.notify(`pi-fence: ${S.state.reason}`, "error");
		}
	});

	pi.on("session_shutdown", (_event, ctx) => {
		ctx.ui.setStatus(STATUS_KEY, undefined);
		if (S.state.scriptPath) host.remove(S.state.scriptPath);
		if (S.state.profilePath) host.remove(S.state.profilePath);
		S.tool = null;
	});
}

export default function (pi: ExtensionAPI) {
	wireFence(pi, { createBashTool, createLocalBashOperations }, defaultEnv(), realHost());
}

/**
 * jj-footer
 *
 * Problem: pi's footer shows `<cwd> (<git branch>)`. In a jj repo that is
 * colocated with git, jj keeps git's HEAD detached, so the slot always reads
 * "(detached)". In a non-colocated jj repo it shows nothing at all.
 *
 * This extension replaces that slot with the jj change id of the working-copy
 * commit (`@`). When the repo has more than one workspace it also appends the
 * current workspace name in jj's own `name@` notation, e.g.
 *
 *     ~/src/foo (urrotmlm)               single workspace
 *     ~/src/foo-wt (urrotmlm second@)    multi-workspace repo
 *
 * How: the built-in FooterComponent calls `footerData.getGitBranch()` on every
 * render, and `ctx.ui.setFooter()` hands its factory that very same live
 * FooterDataProvider. We briefly install a throwaway footer to capture the
 * provider, immediately restore the built-in footer, and shadow
 * `getGitBranch` on the instance. Everything else in the stock footer (token
 * stats, model, context %, extension statuses) is untouched.
 *
 * This leans on pi internals (that setFooter passes the real provider). If
 * that changes, the override silently becomes a no-op and the stock footer
 * keeps working. If the provider ever becomes non-writable we fall back to a
 * `setStatus` entry on the footer's status line instead.
 *
 * Caveat: the capture step restores the built-in footer, so it would clobber
 * another extension's custom footer if one were installed before us.
 *
 * Freshness: jj rewrites `.jj/repo/op_heads/heads` on every operation
 * (including ones run in other terminals), so we watch that directory and
 * re-query. jj is invoked with `--ignore-working-copy` so polling never
 * snapshots the working copy, takes the working-copy lock, or creates
 * operations of its own (which would retrigger the watcher).
 */

import { execFile } from "node:child_process";
import { existsSync, type FSWatcher, readFileSync, realpathSync, statSync, watch } from "node:fs";
import { dirname, join, resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "jj";
const DEBOUNCE_MS = 150;
const JJ_TIMEOUT_MS = 5000;

// One row per workspace: name, recorded root (may be empty for workspaces
// created before jj 0.38), whether its @ is the current workspace's @, and
// the change id of its @.
const TEMPLATE = String.raw`name ++ "\t" ++ if(root, root, "") ++ "\t" ++ if(target.current_working_copy(), "1", "0") ++ "\t" ++ target.change_id().shortest(8) ++ "\n"`;

type JjPaths = { workspaceRoot: string; repoDir: string };
type Row = { name: string; root: string; current: boolean; changeId: string };
type BranchSource = { getGitBranch(): string | null };

/** Walk up from cwd to the nearest jj workspace. */
function findJj(cwd: string): JjPaths | null {
	let dir = resolve(cwd);
	for (;;) {
		const jjDir = join(dir, ".jj");
		if (existsSync(join(jjDir, "working_copy"))) {
			const repoPath = join(jjDir, "repo");
			try {
				// Secondary workspaces store a path (relative to .jj/) to the
				// main workspace's .jj/repo instead of a directory.
				const repoDir = statSync(repoPath).isFile()
					? resolve(jjDir, readFileSync(repoPath, "utf8").trim())
					: repoPath;
				return { workspaceRoot: dir, repoDir };
			} catch {
				return null;
			}
		}
		const parent = dirname(dir);
		if (parent === dir) return null;
		dir = parent;
	}
}

function realpath(p: string): string {
	try {
		return realpathSync(p);
	} catch {
		return p;
	}
}

function runJj(workspaceRoot: string): Promise<string> {
	return new Promise((resolvePromise, reject) => {
		execFile(
			"jj",
			[
				"--ignore-working-copy",
				"--color=never",
				"--no-pager",
				"-R",
				workspaceRoot,
				"workspace",
				"list",
				"-T",
				TEMPLATE,
			],
			{ cwd: workspaceRoot, timeout: JJ_TIMEOUT_MS, encoding: "utf8" },
			(error, stdout) => (error ? reject(error) : resolvePromise(stdout)),
		);
	});
}

function formatLabel(stdout: string, workspaceRoot: string): string | null {
	const rows: Row[] = stdout
		.split("\n")
		.filter(Boolean)
		.map((line) => {
			const [name = "", root = "", current = "", changeId = ""] = line.split("\t");
			return { name, root, current: current === "1", changeId };
		});

	// Normally exactly one row is flagged current. If several workspaces have
	// the same commit checked out they are all flagged, so disambiguate by
	// workspace root when jj recorded one.
	const candidates = rows.filter((r) => r.current);
	const here = realpath(workspaceRoot);
	const me = candidates.find((r) => r.root && realpath(r.root) === here) ?? candidates[0];
	if (!me?.changeId) return null;

	return rows.length > 1 ? `${me.changeId} ${me.name}@` : me.changeId;
}

export default function (pi: ExtensionAPI) {
	let paths: JjPaths | null = null;
	let label: string | null = null;

	let provider: BranchSource | undefined;
	let override: BranchSource["getGitBranch"] | undefined;
	let requestRender: (() => void) | undefined;
	let statusUI: ExtensionContext["ui"] | undefined; // set only in setStatus fallback mode

	let watcher: FSWatcher | undefined;
	let debounce: ReturnType<typeof setTimeout> | undefined;
	let inFlight = false;
	let pending = false;
	// Bumped on shutdown so late jj results from an old session are dropped.
	let generation = 0;

	function publish(next: string | null) {
		if (next === label) return;
		label = next;
		if (statusUI) statusUI.setStatus(STATUS_KEY, label ? `jj ${label}` : undefined);
		requestRender?.();
	}

	async function refresh() {
		if (!paths) return;
		if (inFlight) {
			pending = true;
			return;
		}
		inFlight = true;
		const gen = generation;
		const { workspaceRoot } = paths;
		let next: string | null = null;
		try {
			next = formatLabel(await runJj(workspaceRoot), workspaceRoot);
		} catch {
			// jj missing, repo mid-migration, etc. Fall back to pi's git branch.
		}
		inFlight = false;
		if (gen !== generation) return;
		publish(next);
		if (pending) {
			pending = false;
			void refresh();
		}
	}

	function schedule() {
		if (debounce) clearTimeout(debounce);
		debounce = setTimeout(() => {
			debounce = undefined;
			void refresh();
		}, DEBOUNCE_MS);
		debounce.unref?.();
	}

	function startWatcher(repoDir: string) {
		try {
			watcher = watch(join(repoDir, "op_heads", "heads"), { persistent: false }, schedule);
			watcher.on("error", () => {
				watcher?.close();
				watcher = undefined;
			});
		} catch {
			// No watcher; the agent_end refresh below still keeps us roughly current.
		}
	}

	function installOverride(ctx: ExtensionContext) {
		let captured: { tui: { requestRender(): void }; footerData: unknown } | undefined;
		ctx.ui.setFooter((tui, _theme, footerData) => {
			captured = { tui, footerData };
			return { render: () => [], invalidate() {} };
		});
		ctx.ui.setFooter(undefined);
		if (!captured) return false;

		const target = captured.footerData as BranchSource;
		const original = target.getGitBranch;
		const fn = function (this: BranchSource) {
			return label ?? original.call(this);
		};
		try {
			target.getGitBranch = fn;
		} catch {
			return false;
		}
		if (target.getGitBranch !== fn) return false;

		provider = target;
		override = fn;
		requestRender = () => captured?.tui.requestRender();
		return true;
	}

	function teardown() {
		generation++;
		if (debounce) clearTimeout(debounce);
		debounce = undefined;
		watcher?.close();
		watcher = undefined;
		inFlight = false;
		pending = false;

		// Drop our own-property shadow so the prototype method shows through.
		if (provider && override && provider.getGitBranch === override) {
			delete (provider as Partial<BranchSource>).getGitBranch;
		}
		statusUI?.setStatus(STATUS_KEY, undefined);
		provider = override = requestRender = statusUI = undefined;
		paths = null;
		label = null;
	}

	pi.on("session_start", (_event, ctx) => {
		teardown();
		if (ctx.mode !== "tui") return;

		paths = findJj(ctx.cwd);
		if (!paths) return;

		if (!installOverride(ctx)) statusUI = ctx.ui;
		startWatcher(paths.repoDir);
		void refresh();
	});

	// Belt and braces for filesystems where fs.watch is unreliable.
	pi.on("agent_end", () => {
		if (paths) schedule();
	});

	pi.on("session_shutdown", () => {
		teardown();
	});
}

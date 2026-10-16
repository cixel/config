/**
 * pi-fence test suite.
 *
 * All host interaction is faked (in-memory FenceHost); no sandbox is ever
 * really entered here — that is what tests/pi-fence-hardware.mjs is for.
 * The pi package import is stubbed via tsconfig paths
 * (tests/pi-coding-agent-stub.ts); wiring tests inject fake factories.
 *
 * Run:  cd nix/home-manager/agents/pi && nix run nixpkgs#bun -- test tests/
 */
import { describe, expect, test } from "bun:test";
import {
	bwrapArgs,
	computeZone,
	findRepoRoot,
	goCacheDirs,
	initFence,
	isStrictlyInside,
	probeFence,
	refusedRoot,
	seatbeltProfile,
	sessionScript,
	shQuote,
	staleGenerated,
	wireFence,
	type FenceEnv,
	type FenceHost,
	type FenceState,
} from "../extensions/pi-fence.ts";

// ---------------------------------------------------------------------------
// Fake host
// ---------------------------------------------------------------------------

interface RunResult {
	status: number;
	stdout: string;
}

class FakeHost implements FenceHost {
	/** Paths that exist (post-resolution). */
	existing = new Set<string>();
	/** realpath mappings, e.g. { "/tmp": "/private/tmp" }. */
	links: Record<string, string>;
	files = new Map<string, { content: string; mode: number }>();
	runCalls: { argv: string[]; cwd?: string }[] = [];
	appended: { p: string; line: string }[] = [];
	removed: string[] = [];
	gcCalls: string[] = [];
	failWrites = false;
	runHandler: (argv: string[], cwd?: string) => RunResult = () => ({ status: 0, stdout: "" });

	constructor(opts: { existing?: string[]; links?: Record<string, string> } = {}) {
		this.existing = new Set(opts.existing ?? []);
		this.links = opts.links ?? {};
	}

	exists(p: string) {
		return this.existing.has(p) || this.files.has(p);
	}
	realpath(p: string) {
		const r = this.links[p] ?? p;
		if (!this.existing.has(r)) throw new Error(`ENOENT: ${p}`);
		return r;
	}
	mkdirp(p: string) {
		this.existing.add(p);
	}
	writeFile(p: string, content: string, mode: number) {
		if (this.failWrites) throw new Error(`EROFS: ${p}`);
		this.files.set(p, { content, mode });
	}
	remove(p: string) {
		this.removed.push(p);
		this.files.delete(p);
	}
	run(argv: string[], opts: { cwd?: string }) {
		this.runCalls.push({ argv, cwd: opts.cwd });
		return this.runHandler(argv, opts.cwd);
	}
	append(p: string, line: string) {
		this.appended.push({ p, line });
	}
	gc(dir: string) {
		this.gcCalls.push(dir);
	}
}

const LINUX_ENV: FenceEnv = {
	platform: "linux",
	pid: 42,
	instance: "42",
	home: "/home/user",
	tmpdir: "/tmp",
	agentDir: "/home/user/.pi/agent",
	bash: "/nix/store/bash/bin/bash",
	bwrap: "/nix/store/bwrap/bin/bwrap",
};

const DARWIN_ENV: FenceEnv = {
	...LINUX_ENV,
	platform: "darwin",
	home: "/Users/user",
	tmpdir: "/var/folders/xx/T/",
	agentDir: "/Users/user/.pi/agent",
};

/** Standard macOS-like filesystem: /tmp and /var are symlinked to /private. */
const DARWIN_LINKS = {
	"/tmp": "/private/tmp",
	"/var/tmp": "/private/var/tmp",
	"/var/folders/xx/T/": "/private/var/folders/xx/T",
};
const DARWIN_DIRS = [
	"/Users/user",
	"/Users/user/repo",
	"/private/tmp",
	"/private/var/tmp",
	"/private/var/folders/xx/T",
	"/Users/user/.cache",
	"/Users/user/.local/state/nix",
];

/** Host wired for a happy-path session at /home/user/repo (linux). */
function happyHost(env: FenceEnv = LINUX_ENV): FakeHost {
	const host = new FakeHost({
		existing: [env.home, "/tmp", "/var/tmp", `${env.home}/.cache`, `${env.home}/.local/state/nix`],
	});
	host.existing.add(`${env.home}/repo`);
	host.runHandler = (argv) => {
		if (argv[0] === "jj") return { status: 0, stdout: `${env.home}/repo\n` };
		if (argv[0] === "git") return { status: 128, stdout: "" };
		// probe: the session shell; deny only the write to $HOME itself
		const cmd = argv[2] ?? "";
		if (cmd.includes(`touch '${env.home}/.pi-fence-probe`)) return { status: 1, stdout: "" };
		return { status: 0, stdout: "" };
	};
	return host;
}

// ---------------------------------------------------------------------------
// pure helpers
// ---------------------------------------------------------------------------

describe("isStrictlyInside", () => {
	test.each([
		["/a/b/c", "/a/b", true],
		["/a/b", "/a/b", false],
		["/a/bc", "/a/b", false],
		["/a", "/a/b", false],
	])('%s inside %s -> %s', (p, a, expected) => {
		expect(isStrictlyInside(p, a)).toBe(expected);
	});
});

describe("refusedRoot", () => {
	test("root == home", () => {
		expect(refusedRoot("/home/user", "/home/user")).toMatch(/home directory/);
	});
	test("root is an ancestor of home", () => {
		expect(refusedRoot("/", "/home/user")).toMatch(/ancestor/);
		expect(refusedRoot("/home", "/home/user")).toMatch(/ancestor/);
	});
	test("ordinary repo root is fine", () => {
		expect(refusedRoot("/home/user/repo", "/home/user")).toBeNull();
		expect(refusedRoot("/opt/thing", "/home/user")).toBeNull();
	});
});

describe("computeZone", () => {
	test("linux: root + temp + cache + nix state, deduped", () => {
		const host = new FakeHost({ existing: ["/repo", "/tmp", "/var/tmp", "/home/user", "/home/user/.cache", "/home/user/.local/state/nix"] });
		const zone = computeZone({ root: "/repo", home: "/home/user", tmpdir: "/tmp" }, host);
		expect(zone).toEqual(["/repo", "/tmp", "/var/tmp", "/home/user/.cache", "/home/user/.local/state/nix"]);
	});

	test("darwin: /tmp and /var/tmp resolve through /private, $TMPDIR kept", () => {
		const host = new FakeHost({ existing: DARWIN_DIRS, links: DARWIN_LINKS });
		const zone = computeZone({ root: "/Users/user/repo", home: "/Users/user", tmpdir: "/var/folders/xx/T/" }, host);
		expect(zone).toEqual([
			"/Users/user/repo",
			"/private/tmp",
			"/private/var/tmp",
			"/private/var/folders/xx/T",
			"/Users/user/.cache",
			"/Users/user/.local/state/nix",
		]);
	});

	test("absent optional dirs are skipped", () => {
		const host = new FakeHost({ existing: ["/repo", "/tmp"] });
		const zone = computeZone({ root: "/repo", home: "/home/user", tmpdir: "/tmp" }, host);
		expect(zone).toEqual(["/repo", "/tmp"]);
	});

	test("nested entries are dropped (TMPDIR under /tmp)", () => {
		const host = new FakeHost({ existing: ["/repo", "/tmp", "/tmp/scratch", "/var/tmp"] });
		const zone = computeZone({ root: "/repo", home: "/home/user", tmpdir: "/tmp/scratch" }, host);
		expect(zone).toEqual(["/repo", "/tmp", "/var/tmp"]);
	});

	test("extra (go cache) dirs are added; ones under ~/.cache are folded in", () => {
		const host = new FakeHost({
			existing: ["/repo", "/tmp", "/home/user/.cache", "/home/user/.cache/go-build", "/home/user/gopath/pkg/mod"],
		});
		const zone = computeZone(
			{ root: "/repo", home: "/home/user", tmpdir: "/tmp", extra: ["/home/user/.cache/go-build", "/home/user/gopath/pkg/mod"] },
			host,
		);
		expect(zone).toEqual(["/repo", "/tmp", "/home/user/.cache", "/home/user/gopath/pkg/mod"]);
	});

	test("missing root is an error", () => {
		const host = new FakeHost({ existing: ["/tmp"] });
		expect(() => computeZone({ root: "/gone", home: "/home/user", tmpdir: "/tmp" }, host)).toThrow(/does not exist/);
	});
});

describe("goCacheDirs", () => {
	const AGENT = "/home/user/.pi/agent";
	const answer = (stdout: string, status = 0) => {
		const host = new FakeHost();
		host.runHandler = () => ({ status, stdout });
		return host;
	};

	test("asks go from / with GOTOOLCHAIN=local", () => {
		const host = answer("/home/user/Library/Caches/go-build\n/home/user/gopath/pkg/mod\n");
		expect(goCacheDirs("/home/user", AGENT, host)).toEqual(["/home/user/Library/Caches/go-build", "/home/user/gopath/pkg/mod"]);
		expect(host.runCalls).toEqual([{ argv: ["env", "GOTOOLCHAIN=local", "go", "env", "GOCACHE", "GOMODCACHE"], cwd: "/" }]);
	});

	test("no go / failure -> nothing", () => {
		expect(goCacheDirs("/home/user", AGENT, answer("", 127))).toEqual([]);
	});

	test("GOCACHE=off, relative, home, ancestors and the agent dir are dropped", () => {
		for (const bad of ["off", "rel/dir", "/home/user", "/home", "/", AGENT, `${AGENT}/x`, "/home/user/.pi"]) {
			expect(goCacheDirs("/home/user", AGENT, answer(`${bad}\n/home/user/gopath/pkg/mod\n`))).toEqual(["/home/user/gopath/pkg/mod"]);
		}
	});
});

describe("staleGenerated", () => {
	test("only dead-pid shell/profile files, with or without a runtime nonce", () => {
		const names = [
			"shell-100",
			"profile-100.sb",
			"shell-200-a1b2c3d4",
			"profile-200-a1b2c3d4.sb",
			"shell-300-ffff",
			"sessions.jsonl",
			"shell-notapid",
		];
		const alive = (pid: number) => pid === 200;
		expect(staleGenerated(names, alive)).toEqual(["shell-100", "profile-100.sb", "shell-300-ffff"]);
	});

	test("a live session's files survive no matter how old", () => {
		expect(staleGenerated(["shell-1", "profile-1.sb"], () => true)).toEqual([]);
	});
});

describe("seatbeltProfile", () => {
	const zone = ["/Users/user/repo", "/private/tmp", "/Users/user/.cache"];
	const profile = seatbeltProfile(zone);

	test("default-allow with a global write deny", () => {
		expect(profile).toContain("(allow default)");
		expect(profile).toContain('(deny file-write* (subpath "/"))');
	});

	test("every zone root is re-allowed, plus /dev and the nix daemon socket", () => {
		for (const z of zone) expect(profile).toContain(`(subpath "${z}")`);
		expect(profile).toContain('(subpath "/dev")');
		expect(profile).toContain('(subpath "/nix/var/nix/daemon-socket")');
	});

	test("paths with quotes/backslashes are escaped", () => {
		const p = seatbeltProfile(['/Users/user/we"ird', "/Users/user/back\\slash"]);
		expect(p).toContain('(subpath "/Users/user/we\\"ird")');
		expect(p).toContain('(subpath "/Users/user/back\\\\slash")');
	});
});

describe("bwrapArgs", () => {
	test("ro-bind / first, then dev, then zone binds", () => {
		const args = bwrapArgs(["/repo", "/tmp"]);
		expect(args.slice(0, 7)).toEqual(["--ro-bind", "/", "/", "--dev-bind", "/dev", "/dev", "--die-with-parent"]);
		expect(args.slice(7)).toEqual(["--bind", "/repo", "/repo", "--bind", "/tmp", "/tmp"]);
	});
});

describe("sessionScript", () => {
	test("darwin: sandbox-exec with the profile file", () => {
		const s = sessionScript({
			platform: "darwin",
			zone: ["/Users/user/repo"],
			bash: "/nix/store/bash/bin/bash",
			bwrap: "unused",
			profilePath: "/Users/user/.pi/agent/pi-fence/profile-42.sb",
		});
		expect(s).toBe(
			"#!/bin/sh\n# Generated by pi-fence at session start; do not edit.\n" +
				"exec '/usr/bin/sandbox-exec' -f '/Users/user/.pi/agent/pi-fence/profile-42.sb' '/nix/store/bash/bin/bash' \"$@\"\n",
		);
	});

	test("linux: bwrap argv baked in", () => {
		const s = sessionScript({
			platform: "linux",
			zone: ["/repo", "/tmp"],
			bash: "/nix/store/bash/bin/bash",
			bwrap: "/nix/store/bwrap/bin/bwrap",
			profilePath: "unused",
		});
		expect(s).toContain("exec '/nix/store/bwrap/bin/bwrap' '--ro-bind' '/' '/'");
		expect(s).toContain("'--bind' '/repo' '/repo'");
		expect(s).toContain("'/nix/store/bash/bin/bash' \"$@\"");
		expect(s).not.toContain("sandbox-exec");
	});

	test("paths needing quoting are single-quote escaped", () => {
		expect(shQuote("/home/user/it's here")).toBe("'/home/user/it'\\''s here'");
		const s = sessionScript({
			platform: "linux",
			zone: ["/home/user/my proj"],
			bash: "/b/bash",
			bwrap: "/b/bwrap",
			profilePath: "x",
		});
		expect(s).toContain("'--bind' '/home/user/my proj' '/home/user/my proj'");
	});
});

describe("findRepoRoot", () => {
	const host = (run: FakeHost["runHandler"], existing: string[] = []) => {
		const h = new FakeHost({ existing });
		h.runHandler = run;
		return h;
	};

	test("jj root wins and is realpath'd", () => {
		const h = host(
			(argv) => (argv[0] === "jj" ? { status: 0, stdout: "/checkout\n" } : { status: 1, stdout: "" }),
			["/real/repo"],
		);
		h.links = { "/checkout": "/real/repo" };
		expect(findRepoRoot("/checkout/sub", h)).toBe("/real/repo");
	});

	test("falls back to git when jj fails", () => {
		const h = host(
			(argv) =>
				argv[0] === "git" ? { status: 0, stdout: "/git/repo\n" } : { status: 1, stdout: "" },
			["/git/repo"],
		);
		expect(findRepoRoot("/git/repo", h)).toBe("/git/repo");
	});

	test("no repo -> null", () => {
		const h = host(() => ({ status: 128, stdout: "" }));
		expect(findRepoRoot("/tmp", h)).toBeNull();
	});

	test("non-absolute jj output falls through to git", () => {
		const h = host((argv) =>
			argv[0] === "jj" ? { status: 0, stdout: "relative\n" } : { status: 0, stdout: "/git/repo\n" },
		["/git/repo"],
		);
		expect(findRepoRoot("/git/repo", h)).toBe("/git/repo");
	});
});

describe("probeFence", () => {
	const base = "probe ok when trivial, devnull, in-zone and cache writes work, \$HOME write denied";
	test(base, () => {
		const host = happyHost();
		const r = probeFence("/agent/pi-fence/shell-42", "/home/user/repo", "/home/user", host);
		expect(r).toEqual({ ok: true, detail: "ok" });
	});

	test("sandbox mechanism broken", () => {
		const host = happyHost();
		host.runHandler = () => ({ status: 127, stdout: "" });
		const r = probeFence("/agent/pi-fence/shell-42", "/home/user/repo", "/home/user", host);
		expect(r.ok).toBe(false);
		expect(r.detail).toMatch(/trivial command/);
	});

	test("/dev/null not writable", () => {
		const host = happyHost();
		const inner = host.runHandler;
		host.runHandler = (argv, cwd) =>
			(argv[2] ?? "").includes("/dev/null") ? { status: 1, stdout: "" } : inner(argv, cwd);
		const r = probeFence("/agent/pi-fence/shell-42", "/home/user/repo", "/home/user", host);
		expect(r.detail).toMatch(/\/dev\/null/);
	});

	test("in-zone write fails", () => {
		const host = happyHost();
		const inner = host.runHandler;
		host.runHandler = (argv, cwd) =>
			(argv[2] ?? "").startsWith("d=") ? { status: 1, stdout: "" } : inner(argv, cwd);
		const r = probeFence("/agent/pi-fence/shell-42", "/home/user/repo", "/home/user", host);
		expect(r.detail).toMatch(/inside the zone/);
	});

	test("outside-zone write succeeds -> not enforcing, probe file cleaned up", () => {
		const host = happyHost();
		host.runHandler = () => ({ status: 0, stdout: "" }); // everything allowed: fence broken
		const r = probeFence("/agent/pi-fence/shell-42", "/home/user/repo", "/home/user", host);
		expect(r.ok).toBe(false);
		expect(r.detail).toMatch(/NOT enforcing/);
		expect(host.removed).toEqual(["/home/user/.pi-fence-probe-shell-42"]);
	});
});

// ---------------------------------------------------------------------------
// initFence
// ---------------------------------------------------------------------------

describe("initFence", () => {
	test("happy path (linux): active, session shell written, no profile file", () => {
		const host = happyHost();
		const s = initFence("/home/user/repo", LINUX_ENV, host);
		expect(s.mode).toBe("active");
		expect(s.root).toBe("/home/user/repo");
		expect(s.scriptPath).toBe("/home/user/.pi/agent/pi-fence/shell-42");
		expect(s.profilePath).toBeNull();
		const script = host.files.get("/home/user/.pi/agent/pi-fence/shell-42");
		expect(script?.mode).toBe(0o700);
		expect(script?.content).toContain("bwrap");
		expect(host.files.has("/home/user/.pi/agent/pi-fence/profile-42.sb")).toBe(false);
		expect(host.gcCalls).toEqual(["/home/user/.pi/agent/pi-fence"]);
	});

	test("happy path (darwin): profile written, script references sandbox-exec", () => {
		const host = new FakeHost({ existing: DARWIN_DIRS, links: DARWIN_LINKS });
		host.runHandler = (argv) => {
			if (argv[0] === "jj") return { status: 0, stdout: "/Users/user/repo\n" };
			const cmd = argv[2] ?? "";
			if (cmd.includes("touch '/Users/user/.pi-fence-probe")) return { status: 1, stdout: "" };
			return { status: 0, stdout: "" };
		};
		const s = initFence("/Users/user/repo", DARWIN_ENV, host);
		expect(s.mode).toBe("active");
		expect(s.zone[0]).toBe("/Users/user/repo");
		expect(s.zone).toContain("/private/tmp");
		const profile = host.files.get("/Users/user/.pi/agent/pi-fence/profile-42.sb");
		expect(profile?.content).toContain('(subpath "/Users/user/repo")');
		const script = host.files.get("/Users/user/.pi/agent/pi-fence/shell-42");
		expect(script?.content).toContain("sandbox-exec");
	});

	test("go caches join the zone and are created first", () => {
		const host = happyHost();
		const inner = host.runHandler;
		host.runHandler = (argv, cwd) =>
			argv[0] === "env" ? { status: 0, stdout: "/home/user/.cache/go-build\n/home/user/gopath/pkg/mod\n" } : inner(argv, cwd);
		const s = initFence("/home/user/repo", LINUX_ENV, host);
		expect(s.mode).toBe("active");
		expect(s.zone).toContain("/home/user/gopath/pkg/mod");
		expect(s.zone).not.toContain("/home/user/.cache/go-build"); // under ~/.cache already
		expect(host.existing.has("/home/user/gopath/pkg/mod")).toBe(true);
	});

	test("generated file names carry the runtime instance, not just the pid", () => {
		const host = happyHost();
		const s = initFence("/home/user/repo", { ...LINUX_ENV, instance: "42-deadbeef" }, host);
		expect(s.mode).toBe("active");
		expect(s.scriptPath).toBe("/home/user/.pi/agent/pi-fence/shell-42-deadbeef");
		expect(host.files.has("/home/user/.pi/agent/pi-fence/shell-42")).toBe(false);
	});

	test("first run without ~/.cache still zones it", () => {
		const host = happyHost();
		host.existing.delete("/home/user/.cache");
		const s = initFence("/home/user/repo", LINUX_ENV, host);
		expect(s.zone).toContain("/home/user/.cache");
	});

	test("no repo -> blocked", () => {
		const host = new FakeHost({ existing: ["/home/user", "/tmp"] });
		host.runHandler = () => ({ status: 128, stdout: "" });
		const s = initFence("/home/user", LINUX_ENV, host);
		expect(s.mode).toBe("blocked");
		expect(s.reason).toMatch(/not inside a jj\/git repository/);
	});

	test("repo root is home -> blocked", () => {
		const host = new FakeHost({ existing: ["/home/user", "/tmp", "/var/tmp"] });
		host.runHandler = (argv) =>
			argv[0] === "jj" ? { status: 0, stdout: "/home/user\n" } : { status: 128, stdout: "" };
		const s = initFence("/home/user", LINUX_ENV, host);
		expect(s.mode).toBe("blocked");
		expect(s.reason).toMatch(/home directory/);
	});

	test("probe failure -> down, generated files removed", () => {
		const host = happyHost();
		const inner = host.runHandler;
		// VCS answers still work; the sandbox probe itself fails.
		host.runHandler = (argv, cwd) =>
			argv[0] === "jj" || argv[0] === "git" ? inner(argv, cwd) : { status: 1, stdout: "" };
		const s = initFence("/home/user/repo", LINUX_ENV, host);
		expect(s.mode).toBe("down");
		expect(s.reason).toMatch(/sandbox probe failed/);
		expect(host.removed).toContain("/home/user/.pi/agent/pi-fence/shell-42");
	});

	test("unwritable agent dir -> down", () => {
		const host = happyHost();
		host.failWrites = true;
		const s = initFence("/home/user/repo", LINUX_ENV, host);
		expect(s.mode).toBe("down");
		expect(s.reason).toMatch(/cannot write sandbox profile/);
	});
});

// ---------------------------------------------------------------------------
// wiring
// ---------------------------------------------------------------------------

function fakePi() {
	const handlers = new Map<string, (event: unknown, ctx: unknown) => unknown>();
	const api = {
		tool: null as any,
		registerTool(t: unknown) {
			this.tool = t;
		},
		on(event: string, handler: (event: unknown, ctx: unknown) => unknown) {
			handlers.set(event, handler);
			return () => handlers.delete(event);
		},
	};
	return { api, handlers };
}

function fakeCtx(cwd: string) {
	const statuses = new Map<string, string | undefined>();
	const notifications: { message: string; type?: string }[] = [];
	return {
		cwd,
		hasUI: true,
		statuses,
		notifications,
		ui: {
			setStatus: (key: string, text: string | undefined) => statuses.set(key, text),
			notify: (message: string, type?: string) => notifications.push({ message, type }),
		},
	};
}

function fakeFactories() {
	const calls: { shellPath?: string }[] = [];
	return {
		calls,
		factories: {
			createBashTool: (cwd: string, options?: { operations?: unknown }) => ({
				name: "bash",
				cwd,
				options,
				execute: async (...args: unknown[]) => ({ ran: args[1], cwd, options }),
			}),
			createLocalBashOperations: (options?: { shellPath?: string }) => {
				calls.push({ shellPath: options?.shellPath });
				return { fencedOps: options };
			},
		},
	};
}

describe("wiring", () => {
	test("registers a bash override; session_start fences and exec routes through the session shell", async () => {
		const { api, handlers } = fakePi();
		const host = happyHost();
		const { factories, calls } = fakeFactories();
		wireFence(api as never, factories as never, LINUX_ENV, host);
		expect(api.tool.name).toBe("bash");

		const ctx = fakeCtx("/home/user/repo");
		await (handlers.get("session_start") as any)({}, ctx);
		expect(ctx.statuses.get("fence")).toBe("fence on");
		expect(ctx.notifications).toEqual([]);

		const result = (await api.tool.execute("1", { command: "ls" }, undefined, undefined, ctx)) as any;
		expect(result.ran).toEqual({ command: "ls" });
		expect(calls).toEqual([{ shellPath: "/home/user/.pi/agent/pi-fence/shell-42" }]);
		expect(result.options.operations).toEqual({ fencedOps: { shellPath: "/home/user/.pi/agent/pi-fence/shell-42" } });
		expect(host.appended[0].line).toContain('"mode":"active"');
	});

	test("blocked session: exec refuses, user is notified, footer shows BLOCKED", async () => {
		const { api, handlers } = fakePi();
		const host = new FakeHost({ existing: ["/home/user", "/tmp"] });
		host.runHandler = () => ({ status: 128, stdout: "" });
		wireFence(api as never, fakeFactories().factories as never, LINUX_ENV, host);

		const ctx = fakeCtx("/home/user");
		await (handlers.get("session_start") as any)({}, ctx);
		expect(ctx.statuses.get("fence")).toBe("fence BLOCKED");
		expect(ctx.notifications).toHaveLength(1);
		expect(ctx.notifications[0].type).toBe("error");

		await expect(api.tool.execute("1", { command: "ls" }, undefined, undefined, ctx)).rejects.toThrow(
			/refusing to run bash unfenced.*not inside a jj\/git repository/,
		);
	});

	test("down session: exec refuses after a failed probe", async () => {
		const { api, handlers } = fakePi();
		const host = happyHost();
		wireFence(api as never, fakeFactories().factories as never, LINUX_ENV, host);
		const inner = host.runHandler;
		host.runHandler = (argv, cwd) =>
			argv[0] === "jj" || argv[0] === "git" ? inner(argv, cwd) : { status: 1, stdout: "" };

		const ctx = fakeCtx("/home/user/repo");
		await (handlers.get("session_start") as any)({}, ctx);
		expect(ctx.statuses.get("fence")).toBe("fence DOWN");
		await expect(api.tool.execute("1", { command: "ls" }, undefined, undefined, ctx)).rejects.toThrow(
			/sandbox probe failed/,
		);
	});

	test("exec before session_start initialises lazily", async () => {
		const { api } = fakePi();
		const host = happyHost();
		wireFence(api as never, fakeFactories().factories as never, LINUX_ENV, host);
		const ctx = fakeCtx("/home/user/repo");
		const result = (await api.tool.execute("1", { command: "ls" }, undefined, undefined, ctx)) as any;
		expect(result.ran).toEqual({ command: "ls" });
	});

	test("shutdown clears the footer and removes the generated files", async () => {
		const { api, handlers } = fakePi();
		const host = happyHost();
		wireFence(api as never, fakeFactories().factories as never, LINUX_ENV, host);
		const ctx = fakeCtx("/home/user/repo");
		await (handlers.get("session_start") as any)({}, ctx);
		await (handlers.get("session_shutdown") as any)({}, ctx);
		expect(ctx.statuses.get("fence")).toBeUndefined();
		expect(host.removed).toContain("/home/user/.pi/agent/pi-fence/shell-42");
	});
});

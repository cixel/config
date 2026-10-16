/**
 * pi-fence hardware suite — verifies the REAL kernel boundary, on the real
 * OS sandbox implementation. Complements tests/pi-fence.test.ts (which
 * fakes the host) the way pi-gondolin-resume-test complements its packaged
 * extension tests.
 *
 * Run from anywhere:
 *
 *   cd nix/home-manager/agents/pi
 *   nix run nixpkgs#bun -- tests/pi-fence-hardware.mjs
 *
 * Tool paths default to common locations; override with PI_FENCE_BASH /
 * PI_FENCE_BWRAP (linux). The flake app `pi-fence-test` passes the pinned
 * nixpkgs paths — that is the configuration that ships.
 *
 * Exit 0 = every check passed. Prints one PASS/FAIL/WARN line per check.
 */
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import {
	computeZone,
	defaultEnv,
	initFence,
	realHost,
	sessionScript,
} from "../extensions/pi-fence.ts";

const platform = process.platform;
if (platform !== "darwin" && platform !== "linux") {
	console.error(`SKIP: pi-fence hardware tests only run on macOS and Linux (this is ${platform})`);
	process.exit(0);
}

function firstExisting(...paths) {
	for (const p of paths) {
		try {
			if (readFileSync(p)) return p;
		} catch {}
	}
	return null;
}

const bash =
	process.env.PI_FENCE_BASH ??
	firstExisting("/bin/bash", "/usr/bin/bash", "/run/current-system/sw/bin/bash");
const bwrap = process.env.PI_FENCE_BWRAP ?? firstExisting("/usr/bin/bwrap", "/run/current-system/sw/bin/bwrap");
if (!bash) {
	console.error("FAIL: no bash found (set PI_FENCE_BASH)");
	process.exit(1);
}
if (platform === "linux" && !bwrap) {
	console.error("FAIL: no bwrap found (set PI_FENCE_BWRAP, e.g. via `nix build nixpkgs#bubblewrap`)");
	process.exit(1);
}

const host = realHost();
const scratch = mkdtempSync(join(tmpdir(), "pi-fence-hw-"));
// initFence refuses non-repo roots (by design); make the scratch a repo.
const gitInit = host.run(["git", "init", "-q", "."], { cwd: scratch });
if (gitInit.status !== 0) {
	console.error("FAIL: could not git init the scratch dir");
	process.exit(1);
}
const root = host.realpath(scratch);
const home = homedir();
const env = {
	...defaultEnv(),
	bash,
	bwrap: bwrap ?? "bwrap-not-needed",
	agentDir: join(scratch, "agent"),
};

const state = initFence(root, env, host);
if (state.mode !== "active") {
	console.error(`FAIL: initFence did not activate — ${state.mode}: ${state.reason}`);
	process.exit(1);
}
console.log(`# fenced shell: ${state.scriptPath}`);
console.log(`# zone: ${state.zone.join("  ")}`);

const shell = state.scriptPath;
const probeFile = join(home, `.pi-fence-hw-${process.pid}`);
const results = [];

function check(name, cmd, cwd, expect) {
	const r = host.run([shell, "-c", cmd], { cwd });
	const ok = expect === 0 ? r.status === 0 : r.status !== 0;
	results.push(ok);
	console.log(`${ok ? "PASS" : "FAIL"}  ${name}${ok ? "" : `  (exit ${r.status}, wanted ${expect === 0 ? "success" : "denial"})`}`);
}

check("trivial command runs", "true", root, 0);
check("write inside the repo root", "touch .hw && rm .hw", root, 0);
check("write to /dev/null", "echo ok > /dev/null", root, 0);
check("read /", "ls / > /dev/null", root, 0);
check("write to $HOME denied", `touch ${probeFile}`, home, "fail");
check("write to /etc denied", "touch /etc/.pi-fence-hw", root, "fail");
check("write to ~/.cache (zone) allowed", `touch ${join(home, ".cache", "hw")} && rm ${join(home, ".cache", "hw")}`, root, 0);
check("write to /tmp allowed", "touch /tmp/pi-fence-hw && rm /tmp/pi-fence-hw", root, 0);
check("cwd deletion target visible but $HOME safe: rm -rf ~ denied", `rm -rf ${home}`, root, "fail");

try {
	if (host.exists(join(home, ".ssh"))) {
		check("~/.ssh readable", `ls ${join(home, ".ssh")} > /dev/null`, root, 0);
		check("~/.ssh not writable", `touch ${join(home, ".ssh", ".pi-fence-hw")}`, root, "fail");
	}

	// Background processes must survive the end of a bash call (the agent's
	// `npm run dev &` workflow). On linux this pins the no-pid-namespace
	// choice in bwrapArgs.
	const bg = host.run([shell, "-c", "sleep 60 & echo $!"], { cwd: root });
	const bgPid = Number(bg.stdout.trim());
	if (bg.status === 0 && bgPid > 0) {
		const alive = host.run(["kill", "-0", String(bgPid)], {});
		results.push(alive.status === 0);
		console.log(`${alive.status === 0 ? "PASS" : "FAIL"}  background process survives the bash call`);
		host.run(["kill", String(bgPid)], {});
	} else {
		results.push(false);
		console.log("FAIL  background process survives the bash call (could not start one)");
	}

	if (host.exists("/nix/var/nix/daemon-socket/socket")) {
		const r = host.run([shell, "-c", "nix --extra-experimental-features nix-command store ping --store daemon"], { cwd: root });
		console.log(
			`${r.status === 0 ? "PASS" : "WARN"}  nix daemon reachable inside the fence${
				r.status === 0 ? "" : " (daemon socket present but ping failed — check the seatbelt/bwrap socket rules before relying on nix builds)"
			}`,
		);
	}
} finally {
	rmSync(scratch, { recursive: true, force: true });
	host.remove(probeFile);
	try {
		rmSync(state.scriptPath, { force: true });
		if (state.profilePath) rmSync(state.profilePath, { force: true });
	} catch {}
}

const failed = results.filter((r) => !r).length;
console.log(failed === 0 ? `\nAll ${results.length} checks passed.` : `\n${failed}/${results.length} checks FAILED.`);
process.exit(failed === 0 ? 0 : 1);

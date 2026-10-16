// Actual packaged extension + installed patched SDK + pinned guest integration.
// node --experimental-vm-modules idle-resume.mjs PACKAGE_ROOT IMAGE_PATH [LIVE_EXTENSION_PATH]
// REQUIRE_KVM=1 makes unavailable KVM/HVF a failure rather than a node:test skip.
// QEMU_PATH optionally selects a QEMU binary (qemu-img must still be on PATH).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { constants } from "node:fs";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { test } from "node:test";
import { setTimeout as delay } from "node:timers/promises";
import { importSDK, inputs, loadNativeExtension, readJSON } from "./harness.mjs";

const input = await inputs();
const { packageRoot, imagePath, source, liveExtension } = input;
const requireHardware = process.env.REQUIRE_KVM === "1";
const idlePauseMs = 500;
const hostArch = { x64: "x86_64", arm64: "aarch64" }[process.arch];
const qemuPath = process.env.QEMU_PATH ?? `qemu-system-${hostArch}`;
const accel = process.platform === "darwin" ? "hvf" : "kvm";

async function unavailableHardware() {
  if (!["linux", "darwin"].includes(process.platform) || !hostArch) {
    return `KVM/HVF unsupported on ${process.platform}/${process.arch}`;
  }
  if (process.platform === "linux") {
    try {
      const handle = await fs.open("/dev/kvm", constants.O_RDWR);
      await handle.close();
    } catch (error) {
      if (["ENOENT", "EACCES", "EPERM", "ENODEV"].includes(error.code)) {
        return `/dev/kvm unavailable (${error.code}); grant this user KVM access`;
      }
      throw error;
    }
  }
  // Opening /dev/kvm alone does not prove that nested virtualization is usable.
  // Boot no guest and use QMP to quit cleanly; never fall back to TCG.
  const probe = spawnSync(qemuPath, [
    "-machine", hostArch === "aarch64" ? "virt" : "q35",
    "-accel", accel, "-cpu", "host", "-m", "128M",
    "-nodefaults", "-display", "none", "-S", "-qmp", "stdio",
  ], {
    input: '{"execute":"qmp_capabilities"}\n{"execute":"quit"}\n',
    encoding: "utf8",
    timeout: 10_000,
  });
  assert.ifError(probe.error); // Missing QEMU is a broken runner, not absent hardware.
  if (probe.status === 0) return undefined;
  if (/(failed to initialize (kvm|hvf)|could not access kvm|permission denied|invalid accelerator hvf|hvf.*not supported|hv_vm_create.*failed|kvm.*not supported)/i.test(probe.stderr)) {
    return `${accel.toUpperCase()} unavailable: ${probe.stderr.trim()}`;
  }
  assert.fail(`QEMU accelerator probe failed (${probe.status}): ${probe.stderr}`);
}

async function waitForPause(controller, signal) {
  const deadline = performance.now() + 15_000;
  while (performance.now() < deadline) {
    signal.throwIfAborted();
    assert.ok(controller.child, "QEMU exited while waiting for idle pause");
    assert.equal(controller.qmpIdleDisabled, false, "SDK disabled QMP idle pausing");
    if (controller.paused === true && controller.pauseInProgress === false) {
      // paused is set by the real SDK only after QMP stop succeeds. Confirm QEMU
      // agrees; this query is read-only and does not resume the controller.
      const status = await controller.runQmpCommand("query-status");
      assert.equal(status.running, false);
      assert.equal(status.status, "paused");
      return;
    }
    await delay(25, undefined, { signal });
  }
  assert.fail("actual SDK controller never reached paused=true after QMP stop");
}

async function closeVM(vm) {
  // Even a failing startup/exec must not leave QEMU alive. Normally SDK.close()
  // also removes its overlay. A hung teardown gets an explicit failure + kill.
  let timer;
  try {
    await Promise.race([
      vm.close(),
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          vm.server?.controller?.child?.kill("SIGKILL");
          reject(new Error("VM.close() exceeded 15 seconds; killed QEMU"));
        }, 15_000);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

test("packaged extension survives three actual QEMU idle pause/time-sync resumes", {
  timeout: 180_000,
}, async (t) => {
  assert.ok(!source.includes("@gondolinGuestImage@"));
  assert.ok(source.includes(JSON.stringify(imagePath)), "extension must bake the tested store image");
  if (liveExtension) assert.equal(await fs.readFile(liveExtension, "utf8"), source);
  const image = await readJSON(path.join(imagePath, "manifest.json"));
  const provenance = await readJSON(path.join(imagePath, "provenance.json"));
  assert.equal(image.config.arch, hostArch, "hardware test requires native guest architecture");
  assert.equal(image.runtimeDefaults.rootfsMode, "cow");
  const reason = await unavailableHardware();
  if (reason) {
    if (requireHardware) assert.fail(`REQUIRE_KVM=1: ${reason}`);
    t.skip(`${reason}; set REQUIRE_KVM=1 to require accelerated integration`);
    return;
  }

  const sdk = await importSDK(packageRoot);
  const sdkManifest = await readJSON(path.join(
    packageRoot, "node_modules/@earendil-works/gondolin/package.json",
  ));
  assert.equal(provenance.sdkVersion, sdkManifest.version);
  assert.equal(provenance.arch, hostArch);
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "gondolin-extension-idle-"));
  const previousCwd = process.cwd();
  const token = randomUUID();
  const cowFile = `/root/.gondolin-idle-${token}`;
  const rootfsPath = path.join(imagePath, image.assets.rootfs);
  const rootfsBefore = await fs.stat(rootfsPath);
  const created = [];
  const createOptions = [];
  const logs = [];
  const originalCreate = sdk.VM.create;
  let extension;
  let overlay;
  try {
    await fs.writeFile(path.join(workspace, "host-marker"), `${token}\n`);
    // Do not fake VM, filesystem, exec, pause, resume or protocol methods.
    // This wrapper only adds hardware-test controls to the actual VM.create.
    sdk.VM.create = async function (options) {
      createOptions.push(options);
      assert.equal(options.sandbox.imagePath, imagePath);
      assert.equal(options.rootfs.mode, "cow");
      assert.ok(options.vfs.mounts["/workspace"] instanceof sdk.RealFSProvider);
      const guest = await originalCreate.call(sdk.VM, {
        ...options,
        sandbox: {
          ...options.sandbox,
          vmm: "qemu",
          qemuPath,
          accel,
          qemuIdlePauseMs: idlePauseMs, // Linux defaults to disabled: explicit is essential.
          netEnabled: false,
          debug: ["protocol", "exec"],
        },
        startTimeoutMs: 45_000,
        debugLog(component, message) { logs.push({ component, message }); },
      });
      created.push(guest); // Capture before any boot/exec can fail.
      if (t.signal.aborted) {
        await closeVM(guest);
        t.signal.throwIfAborted();
      }
      return guest;
    };
    process.chdir(workspace);
    extension = await loadNativeExtension({
      ...input, cwd: workspace,
    });
    process.chdir(previousCwd);
    // Enter through user_bash before eager startup: host fallback is forbidden.
    const { operations } = await extension.emit("user_bash");
    await extension.emit("session_start");
    assert.equal(created.length, 1);
    assert.equal(createOptions.length, 1);
    const guest = created[0];
    assert.ok(guest instanceof sdk.VM);
    assert.equal(guest.rootDisk.format, "qcow2");
    assert.equal(guest.rootDisk.deleteOnClose, true);
    overlay = guest.rootDisk.path;
    assert.notEqual(overlay, rootfsPath);
    assert.ok(!overlay.startsWith("/nix/store/"));
    const controller = guest.server.controller; // TS private, intentionally observable in pinned SDK.
    assert.equal(controller.idlePauseMs, idlePauseMs);
    assert.equal(typeof controller.paused, "boolean");
    assert.equal(typeof controller.runQmpCommand, "function");

    const execute = async (command, timeout = 25) => {
      const chunks = [];
      const result = await operations.exec(command, workspace, {
        signal: t.signal,
        timeout,
        onData(data) { chunks.push(Buffer.from(data)); },
      });
      const output = Buffer.concat(chunks).toString("utf8");
      assert.equal(result.exitCode, 0, output);
      return output;
    };
    const assertClockAndVfs = async (cycle, initial = false) => {
      const before = Date.now();
      const output = await execute([
        "set -eu",
        initial
          ? `test ! -e '${cowFile}'; printf '%s\\n' '${token}' > '${cowFile}'`
          : `test "$(cat '${cowFile}')" = '${token}'`,
        `test "$(cat /workspace/host-marker)" = '${token}'`,
        "test \"$PWD\" = /workspace",
        `printf '%s\\n' '${cycle}' >> /workspace/guest-marker`,
        "printf 'clock='; date +%s",
        `printf 'cycle=%s\\n' '${cycle}'`,
      ].join("\n"));
      const after = Date.now();
      const match = /^clock=(\d+)$/m.exec(output);
      assert.ok(match, `missing guest clock: ${output}`);
      const milliseconds = Number(match[1]) * 1000;
      assert.ok(milliseconds >= before - 2_000 && milliseconds <= after + 2_000,
        `guest clock ${milliseconds} disagrees with host [${before}, ${after}]`);
      assert.match(output, new RegExp(`^cycle=${cycle}$`, "m"));
      assert.equal(await fs.readFile(path.join(workspace, "guest-marker"), "utf8"),
        Array.from({ length: cycle + 1 }, (_, n) => `${n}\n`).join(""));
    };

    // VFS stays enabled throughout: real RealFSProvider + sandboxfs round trips.
    await assertClockAndVfs(0, true);
    const handshakes = [];
    for (let cycle = 1; cycle <= 3; cycle++) {
      await waitForPause(controller, t.signal);
      // Spend > the clock tolerance actually paused so a missing guest clock
      // correction cannot pass merely because the idle interval was short.
      await delay(3_100, undefined, { signal: t.signal });
      assert.equal(controller.paused, true, "VM must remain paused until the extension exec");
      const logStart = logs.length;
      await assertClockAndVfs(cycle);
      const handshake = logs.slice(logStart).filter(({ component, message }) =>
        component === "protocol" && /virtio rx t=time_sync_done\b/.test(message));
      assert.equal(handshake.length, 1,
        `cycle ${cycle}: need exactly one real guest time_sync_done handshake`);
      handshakes.push(handshake[0].message);
      assert.equal(controller.paused, false, `cycle ${cycle}: controller did not resume`);
      assert.equal(controller.syncPending, false, `cycle ${cycle}: time sync did not finish`);
      assert.equal(guest.server.pendingTimeSync, null);
      t.diagnostic(`cycle ${cycle}: observed QMP paused -> guest time_sync_done -> successful extension exec + clock/VFS`);
    }
    assert.equal(created.length, 1, "resuming must not replace the VM");
    assert.equal(new Set(handshakes).size, 3, "each resume needs its own time-sync request ID");
    // The base Alpine contains these pinned release helpers (plus any guest tools below).
    const hashes = await execute(
      "sha256sum /usr/bin/sandboxd /usr/bin/sandboxfs /usr/bin/sandboxingress /usr/bin/sandboxssh",
    );
    for (const [name, expected] of Object.entries(provenance.helpers.manifest.checksums)) {
      assert.match(hashes, new RegExp(`^${expected}  /usr/bin/${name}$`, "m"));
    }
    if (provenance.guest) {
      // Baked tools run from /usr/local/bin, and the guest's own Nix DB
      // accepts the host-copied closure byte-for-byte (narHash check).
      const versionCommands = { nix: "nix --version", jujutsu: "jj --version", go: "go version" };
      const checked = provenance.guest.tools.filter((tool) => versionCommands[tool.name]);
      const output = await execute([
        "set -eu",
        ...checked.map((tool) => versionCommands[tool.name]),
        ...(checked.some((tool) => tool.name === "nix")
          ? [`nix store verify --recursive --no-trust '${provenance.guest.env}'`]
          : []),
        "echo guest-tools-ok",
      ].join("\n"), 120);
      assert.match(output, /^guest-tools-ok$/m);
      for (const tool of checked) {
        assert.ok(output.includes(tool.version), `guest ${tool.name} ${tool.version} not reported:\n${output}`);
      }
      t.diagnostic(`guest tools: ${provenance.guest.tools.map((tool) => `${tool.name} ${tool.version}`).join(", ")}`);
    }
  } catch (error) {
    t.diagnostic(logs.slice(-40).map(({ component, message }) => `[${component}] ${message}`).join("\n"));
    throw error;
  } finally {
    sdk.VM.create = originalCreate;
    try {
      // Close captured actual VMs even if extension setup or a hook failed.
      for (const guest of created) await closeVM(guest);
    } finally {
      process.chdir(previousCwd);
      await fs.rm(workspace, { recursive: true, force: true });
    }
  }
  if (overlay) {
    await assert.rejects(fs.stat(overlay), { code: "ENOENT" }, "VM.close must remove its COW overlay");
  }
  const rootfsAfter = await fs.stat(rootfsPath);
  assert.equal(rootfsAfter.size, rootfsBefore.size);
  assert.equal(rootfsAfter.mtimeMs, rootfsBefore.mtimeMs, "immutable base rootfs was modified");
});

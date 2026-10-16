// Use the already Nix-installed SDK; no npm install or image download.
// node gondolin-idle-resume-repro.mjs /path/to/sdk/dist/src/index.js /path/to/image
import assert from "node:assert/strict";
import path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { pathToFileURL } from "node:url";

const [sdkEntry, imageDir] = process.argv.slice(2);
if (!sdkEntry || !imageDir) {
  console.error("Usage: node gondolin-idle-resume-repro.mjs SDK_ENTRY IMAGE_DIR");
  process.exit(2);
}
const idlePauseMs = Number(process.env.IDLE_PAUSE_MS ?? 500);
assert.ok(Number.isFinite(idlePauseMs) && idlePauseMs >= 0);
const expected = process.env.EXPECT_RESUME ?? "success";
assert.ok(["success", "failure"].includes(expected));
const { VM } = await import(pathToFileURL(path.resolve(sdkEntry)).href);
const vm = await VM.create({
  sandbox: {
    vmm: "qemu",
    imagePath: path.resolve(imageDir),
    qemuIdlePauseMs: idlePauseMs,
    netEnabled: false,
    console: "none",
    debug: ["protocol", "exec"],
    ...(process.env.QEMU_PATH ? { qemuPath: process.env.QEMU_PATH } : {}),
    ...(process.env.QEMU_ACCEL ? { accel: process.env.QEMU_ACCEL } : {}),
  },
  rootfs: { mode: "cow" },
  vfs: null,
  debugLog(component, message) {
    if (component === "exec" ||
        (component === "protocol" && /rx t=(error|time_sync_done)\b/.test(message))) {
      console.log(new Date().toISOString(), component, message.trim());
    }
  },
});
const probe = () => vm.exec(["/bin/date", "+%s"], {
  signal: AbortSignal.timeout(15_000),
});
try {
  const first = await probe();
  assert.equal(first.exitCode, 0, "initial exec must work");
  console.log("initial exec:", first.stdout.trim());
  for (let cycle = 1; cycle <= 3; cycle++) {
    await delay(Math.max(1_000, idlePauseMs + 1_000));
    const start = performance.now();
    let error;
    let result;
    try {
      result = await probe();
    } catch (err) {
      error = err;
    }
    console.log(`cycle ${cycle}: ${Math.round(performance.now() - start)} ms`,
      error ? String(error) : `exit=${result.exitCode} time=${result.stdout.trim()}`);
    if (expected === "failure") {
      assert.ok(error, "expected the stock-image resume to fail");
      assert.match(String(error), /sandbox_resume_failed.*guest time sync timed out/s);
    } else {
      if (error) throw error;
      assert.equal(result.exitCode, 0);
      const guestSeconds = Number(result.stdout.trim());
      assert.ok(Number.isFinite(guestSeconds));
      assert.ok(Math.abs(guestSeconds - Date.now() / 1_000) < 3,
        "guest clock must agree with host after resume");
    }
  }
  console.log(`PASS: three cycles with expected ${expected}; idlePauseMs=${idlePauseMs}`);
} finally {
  await vm.close();
}

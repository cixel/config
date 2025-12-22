// Node >=22.19, no Pi, QEMU, image cache, network or hardware required:
// node --experimental-vm-modules extension.mjs PACKAGE_ROOT IMAGE_PATH [LIVE_EXTENSION_PATH]
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";
import { importSDK, inputs, loadNativeExtension, mockExtension, readJSON } from "./harness.mjs";

const input = await inputs();
const { packageRoot, imagePath, source, liveExtension } = input;

test("packaged extension bakes the explicit immutable image path", async () => {
  assert.ok(!source.includes("@gondolinGuestImage@"));
  assert.ok(source.includes(JSON.stringify(imagePath)), "wrong or absent baked image");
  if (liveExtension) {
    assert.equal(await fs.readFile(liveExtension, "utf8"), source,
      "live Pi extension differs from the tested package");
  }
});

test("manifest, lock, installed SDK and image provenance use the same pins", async () => {
  const manifest = await readJSON(path.join(packageRoot, "package.json"));
  const lock = await readJSON(path.join(packageRoot, "package-lock.json"));
  const sdk = await readJSON(path.join(
    packageRoot, "node_modules/@earendil-works/gondolin/package.json",
  ));
  assert.equal(manifest.dependencies["@earendil-works/gondolin"], manifest.version);
  assert.equal(lock.version, manifest.version);
  assert.equal(lock.packages[""].version, manifest.version);
  assert.equal(lock.packages[""].dependencies["@earendil-works/gondolin"], manifest.version);
  assert.equal(lock.packages["node_modules/@earendil-works/gondolin"].version, manifest.version);
  assert.equal(sdk.version, manifest.version);
  const image = await readJSON(path.join(imagePath, "manifest.json"));
  const provenance = await readJSON(path.join(imagePath, "provenance.json"));
  assert.equal(image.version, 1);
  assert.ok(["x86_64", "aarch64"].includes(image.config.arch));
  assert.equal(image.runtimeDefaults.rootfsMode, "cow");
  assert.equal(provenance.schema, 1);
  assert.equal(provenance.sdkVersion, sdk.version);
  assert.equal(provenance.arch, image.config.arch);
  const helpers = provenance.helpers.manifest;
  assert.equal(helpers.schema, 1);
  assert.equal(helpers.kind, "gondolin-sandbox-helpers");
  assert.equal(helpers.gondolinVersion, sdk.version);
  assert.equal(helpers.arch, image.config.arch);
  assert.deepEqual(Object.keys(helpers.checksums).sort(),
    ["sandboxd", "sandboxfs", "sandboxingress", "sandboxssh"]);
  for (const checksum of Object.values(helpers.checksums)) {
    assert.match(checksum, /^[a-f0-9]{64}$/);
  }
  // Guest tools, when configured, live inside the rootfs asset (see
  // provenance.guest); the image is still these three assets plus metadata.
  // Asset paths must stay in the immutable image and exist without a cache.
  for (const name of ["kernel", "initramfs", "rootfs"]) {
    const asset = image.assets[name];
    assert.equal(typeof asset, "string");
    assert.ok(!path.isAbsolute(asset) && !asset.split("/").includes(".."));
    assert.ok((await fs.stat(path.join(imagePath, asset))).size > 0);
    assert.match(image.checksums[name], /^[a-f0-9]{64}$/);
  }
});

test("actual SDK resolver ignores poisoned image environment/cache offline", async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), "gondolin-image-resolution-"));
  const overrides = {
    HOME: tmp,
    XDG_CACHE_HOME: path.join(tmp, "cache"),
    GONDOLIN_IMAGE_STORE: path.join(tmp, "missing-image-store"),
    GONDOLIN_GUEST_DIR: path.join(tmp, "missing-override"),
    GONDOLIN_DEFAULT_IMAGE: "must-not-be-used:latest",
    GONDOLIN_IMAGE_REGISTRY_URL: "https://must-not-be-used.invalid/registry.json",
  };
  const previous = Object.fromEntries(Object.keys(overrides).map((key) => [key, process.env[key]]));
  const originalFetch = globalThis.fetch;
  try {
    Object.assign(process.env, overrides);
    globalThis.fetch = () => { throw new Error("image resolver attempted network access"); };
    const images = await import(pathToFileURL(path.join(
      packageRoot, "node_modules/@earendil-works/gondolin/dist/src/images.js",
    )).href);
    const resolved = await images.ensureImageSelector(imagePath);
    assert.equal(resolved.source, "path");
    assert.equal(resolved.assetDir, imagePath);
    assert.deepEqual(await fs.readdir(tmp), [], "explicit image resolution populated a cache");
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    await fs.rm(tmp, { recursive: true, force: true });
  }
});

test("eager/lazy startup shares one VM with explicit image, COW and VFS", async () => {
  const extension = await mockExtension(input);
  try {
    const [, userBash] = await Promise.all([
      extension.emit("session_start"),
      extension.emit("user_bash"),
    ]);
    assert.equal(extension.calls.create.length, 1);
    const options = extension.calls.create[0];
    assert.equal(options.sandbox.imagePath, imagePath);
    assert.ok(!Object.hasOwn(options.sandbox, "qemuIdlePauseMs"),
      "production must retain the SDK's default automatic idle pausing");
    assert.equal(options.rootfs.mode, "cow", "COW belongs at VMOptions.rootfs, not sandbox");
    assert.equal(options.vfs.mounts["/workspace"].root, "/host/project");
    assert.ok(userBash.operations);
    assert.deepEqual([...extension.tools.keys()].sort(), ["bash", "edit", "read", "write"]);
    const prompt = await extension.emit("before_agent_start", {
      systemPrompt: "Current working directory: /host/project",
    });
    assert.ok(prompt.systemPrompt.includes("Current working directory: /workspace"));
    assert.ok(extension.notifications.some(([message]) =>
      message.includes(`${imagePath}/provenance.json`)),
    "startup notification must expose the pinned image provenance");
  } finally {
    await extension.emit("session_shutdown");
  }
  assert.equal(extension.calls.closed, 1);
});

test("workspace tools accept host/guest paths, reject escapes and omit host env", async () => {
  const extension = await mockExtension(input);
  try {
    for (const p of ["/host/project/file", "/workspace/file"]) {
      await extension.execute("read", { path: p });
      assert.equal(extension.calls.fs.at(-1)[1], "/workspace/file");
    }
    await extension.execute("read", { path: "/host/project/..valid-name" });
    assert.equal(extension.calls.fs.at(-1)[1], "/workspace/..valid-name");
    await extension.execute("edit", { path: "/workspace/nested/file" });
    assert.equal(extension.calls.fs.at(-1)[1], "/workspace/nested/file");
    await extension.execute("write", { path: "/workspace/nested/file", content: "new content" });
    assert.equal(extension.calls.fs.at(-2)[1], "/workspace/nested");
    assert.equal(extension.calls.fs.at(-1)[1], "/workspace/nested/file");
    for (const p of [
      "/host/other/file", "/workspace/../outside", "/workspace-sibling/file",
      "/host/project/../outside", "/workspace/nested/../../outside",
    ]) {
      for (const tool of ["read", "write", "edit"]) {
        await assert.rejects(extension.execute(tool, { path: p, content: "no" }),
          /path escapes workspace/);
      }
    }
    const { operations } = await extension.emit("user_bash");
    await operations.exec("echo guest", "/workspace/nested", { onData() {} });
    assert.deepEqual(extension.calls.exec.at(-1).command, ["/bin/bash", "-lc", "echo guest"]);
    assert.equal(extension.calls.exec.at(-1).options.cwd, "/workspace/nested");
    assert.ok(!Object.hasOwn(extension.calls.exec.at(-1).options, "env"));
    await assert.rejects(operations.exec("echo forbidden", "/outside", { onData() {} }),
      /path escapes workspace/);
    assert.equal(extension.calls.exec.length, 1, "rejected commands reached the guest");
  } finally {
    await extension.emit("session_shutdown");
  }
});

test("projects beneath /workspace retain host-relative path precedence", async () => {
  const extension = await mockExtension(input, { cwd: "/workspace/project" });
  try {
    await extension.execute("read", { path: "/workspace/project/file" });
    assert.equal(extension.calls.fs.at(-1)[1], "/workspace/file");
  } finally {
    await extension.emit("session_shutdown");
  }
});

test("startup fails closed for user ! and all tools, before and after session_start", async () => {
  const failure = new Error("pinned image could not start");
  const extension = await mockExtension(input, { createError: failure });
  await assert.rejects(extension.emit("user_bash"), (error) => error === failure);
  await assert.rejects(extension.emit("session_start"), (error) => error === failure);
  await assert.rejects(extension.emit("user_bash"), (error) => error === failure);
  for (const name of ["read", "write", "edit", "bash"]) {
    await assert.rejects(extension.execute(name, { path: "/workspace/file", command: "true" }),
      (error) => error === failure);
  }
  await extension.emit("session_shutdown");
  assert.equal(extension.calls.create.length, 1);
  assert.equal(extension.calls.exec.length, 0);
  assert.equal(extension.calls.fs.length, 0);
  assert.equal(extension.calls.closed, 0);
});

test("native hardware loader stubs only Pi and keeps SDK exec arguments in the host realm", async () => {
  const sdk = await importSDK(packageRoot);
  const originalCreate = sdk.VM.create;
  let creates = 0;
  let execs = 0;
  let closes = 0;
  let extension;
  try {
    // No hardware in this harness regression: only this nonhardware test
    // replaces create's return value. idle-resume calls originalCreate.
    sdk.VM.create = async (options) => {
      creates++;
      assert.equal(options.sandbox.imagePath, imagePath);
      assert.ok(options.vfs.mounts["/workspace"] instanceof sdk.RealFSProvider);
      return {
        exec(argv, options) {
          execs++;
          assert.equal(argv.constructor, Array, "cbor2 requires the SDK realm's Array constructor");
          assert.equal(options.constructor, Object);
          assert.deepEqual(argv, ["/bin/bash", "-lc", "echo native"]);
          const result = Promise.resolve({ exitCode: 0 });
          result.output = async function* () { yield { data: Buffer.from("native\n") }; };
          return result;
        },
        async close() { closes++; },
      };
    };
    extension = await loadNativeExtension({ ...input, cwd: process.cwd() });
    const { operations } = await extension.emit("user_bash");
    let output = "";
    const result = await operations.exec("echo native", process.cwd(), {
      onData(data) { output += data.toString(); },
    });
    assert.equal(result.exitCode, 0);
    assert.equal(output, "native\n");
    assert.equal(creates, 1, "native extension must import the actual packaged SDK class");
    assert.equal(execs, 1);
  } finally {
    try {
      if (extension) await extension.emit("session_shutdown");
    } finally {
      sdk.VM.create = originalCreate;
    }
  }
  assert.equal(closes, 1);
});

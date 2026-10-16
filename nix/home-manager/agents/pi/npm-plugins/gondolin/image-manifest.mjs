// Host-only release-artifact composition. The pinned SDK's exported algorithms
// are authoritative for both image and helper build IDs; no npm install needed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const HELPER_NAMES = ["sandboxd", "sandboxfs", "sandboxssh", "sandboxingress"];
const ASSET_NAMES = ["kernel", "initramfs", "rootfs", "krunKernel", "krunInitrd"];
const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const json = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const writeJson = (file, value) => fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
const sameKeys = (actual, expected, label) =>
  assert.deepEqual(Object.keys(actual).sort(), [...expected].sort(), label);
const hashString = (value) => assert.match(value, /^[0-9a-f]{64}$/, "SHA256 must be lowercase hex");

function command(program, args, options = {}) {
  const result = spawnSync(program, args, {
    encoding: "utf8",
    // Guest-tool scripts echo tens of thousands of debugfs commands.
    maxBuffer: 1024 * 1024 * 1024,
    ...options,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, `${program} failed:\n${result.stdout}\n${result.stderr}`);
  return result;
}

// Unlike a generic tar extraction, accept only regular files/directories, no
// links, traversal, duplicate names, hidden files or unrecognized payloads.
async function readArchive(file, pin, tar, computeFileHash) {
  hashString(pin.sha256);
  assert.equal(computeFileHash(file), pin.sha256, `archive checksum: ${file}`);
  const files = new Map();
  for (const entry of tar.parseTar(await tar.decompressTarGz(file))) {
    const name = entry.name.replace(/^\.\//, "").replace(/\/$/, "");
    if (name === "" || name === ".") {
      assert.equal(entry.type, 5, "archive root must be a directory");
      continue;
    }
    assert.match(name, /^[A-Za-z0-9_-][A-Za-z0-9_./-]*$/, `unsafe archive path: ${name}`);
    assert(!name.split("/").some((part) => part === ".." || part === "." || part === ""));
    assert(entry.type === 0 || entry.type === 5, `archive contains non-file: ${name}`);
    assert(!files.has(name), `duplicate archive member: ${name}`);
    files.set(name, entry);
  }
  return files;
}

function regular(files, name) {
  const entry = files.get(name);
  assert(entry?.type === 0 && Buffer.isBuffer(entry.content), `missing regular file: ${name}`);
  return entry.content;
}

function inventory(files, expectedFiles, expectedDirs = []) {
  sameKeys(Object.fromEntries(files), [...expectedFiles, ...expectedDirs], "archive inventory");
  for (const name of expectedDirs) assert.equal(files.get(name)?.type, 5, `directory: ${name}`);
}

// This also checks actual ELF architecture, not just the manifest's claim.
export function validateHelperManifest(manifest, files, arch, pin, sdkVersion, computeBuildId) {
  assert.equal(manifest.schema, 1, "helper manifest schema");
  assert.equal(manifest.kind, "gondolin-sandbox-helpers", "helper manifest kind");
  assert.equal(manifest.gondolinVersion, sdkVersion, "SDK/helper version mismatch");
  assert.equal(manifest.arch, arch, "helper architecture");
  assert.equal(manifest.target, pin.target, "helper target");
  assert.equal(manifest.zigVersion, pin.zigVersion, "helper Zig version");
  sameKeys(manifest.checksums, HELPER_NAMES, "helper checksum inventory");
  for (const name of HELPER_NAMES) {
    const bytes = regular(files, `bin/${name}`);
    hashString(manifest.checksums[name]);
    assert.equal(sha256(bytes), manifest.checksums[name], `helper checksum: ${name}`);
    assert(bytes.length >= 20 && bytes.subarray(0, 6).equals(Buffer.from([0x7f, 0x45, 0x4c, 0x46, 2, 1])),
      `helper must be little-endian ELF64: ${name}`);
    assert.equal(bytes.readUInt16LE(18), arch === "aarch64" ? 183 : 62, `helper ELF architecture: ${name}`);
  }
  assert.equal(computeBuildId({ arch, checksums: manifest.checksums }), pin.buildId, "helper buildId");
}

// debugfs reports some command failures with exit status 0. Besides checking its
// diagnostics, independently dump/hash/stat every installed file afterwards.
function debugfs(image, commands, work, writable) {
  const script = path.join(work, "debugfs.commands");
  fs.writeFileSync(script, `${commands.join("\n")}\n`);
  const result = command("debugfs", [...(writable ? ["-w"] : []), "-f", script, image], {
    env: { ...process.env, E2FSPROGS_FAKE_TIME: "1", TZ: "UTC", LC_ALL: "C" },
  });
  // "exists": mkdir/write onto an existing name leaks an allocated inode.
  assert(!/error|not found|not open|not supported|usage:|invalid|short (read|write)|no space|exists/i.test(result.stderr),
    `debugfs diagnostics:\n${result.stderr}`);
  return result.stdout;
}

// --- Guest tools (/nix store closure + small root overlay) -----------------
//
// Nix builds a Linux "guest root" (nix.conf, /usr/local/bin links, a loaded
// Nix DB) and lists the closure it needs. Copy both into the rootfs with the
// same host-only debugfs approach as the helpers. Ownership is root, times
// come from set_current_time 1, and modes are normalized so the result does
// not depend on how the build host's store happens to present them.

const BLOCK_SIZE = 4096;
const ROOTFS_HEADROOM_MIN_MB = 64;

// debugfs (ss) argument quoting: wrap in quotes, double embedded quotes.
// Newlines/NULs cannot be expressed, so refuse them rather than mis-address.
function quote(value) {
  assert(!/[\n\r\0]/.test(value), `debugfs cannot address path: ${JSON.stringify(value)}`);
  return `"${value.replaceAll('"', '""')}"`;
}

function normalizedMode(type, executable, kind) {
  if (type === "symlink") return "0120777";
  if (kind === "store") return type === "dir" ? "040555" : executable ? "0100555" : "0100444";
  return type === "dir" ? "040755" : executable ? "0100755" : "0100644";
}

// Preorder walk (parents first), sorted for a deterministic allocation order.
function walkTree(host, guest, kind, entries) {
  const st = fs.lstatSync(host);
  const entry = { host, guest, kind };
  if (st.isDirectory()) {
    const names = fs.readdirSync(host).sort();
    entries.push(Object.assign(entry, {
      type: "dir",
      // ext4 dirent: 8-byte header + name padded to 4; plus "." and "..".
      dirBytes: 24 + names.reduce((sum, name) => sum + 8 + Math.ceil(Buffer.byteLength(name) / 4) * 4, 0),
    }));
    for (const name of names) {
      // Darwin's case-insensitive store renames colliding NAR entries to
      // `name~nix~case~hack~N`; the Linux guest wants the real names.
      const guestName = kind === "store" ? name.replace(/~nix~case~hack~\d+$/, "") : name;
      walkTree(path.join(host, name), path.posix.join(guest, guestName), kind, entries);
    }
  } else if (st.isFile()) {
    entries.push(Object.assign(entry, { type: "file", size: st.size, executable: (st.mode & 0o111) !== 0 }));
  } else if (st.isSymbolicLink()) {
    entries.push(Object.assign(entry, { type: "symlink", target: fs.readlinkSync(host) }));
  } else {
    assert.fail(`guest tree contains a special file: ${host}`);
  }
  entry.mode = normalizedMode(entry.type, entry.executable, kind);
  return entries;
}

function entryBlocks(entry) {
  if (entry.type === "file") return Math.ceil(entry.size / BLOCK_SIZE);
  if (entry.type === "dir") return Math.max(1, Math.ceil(entry.dirBytes / BLOCK_SIZE));
  return Buffer.byteLength(entry.target) >= 60 ? 1 : 0; // slow symlink
}

function superblock(image) {
  const out = command("dumpe2fs", ["-h", image]).stdout;
  const field = (name) => {
    const match = out.match(new RegExp(`^${name}:\\s+(\\d+)$`, "m"));
    assert(match, `dumpe2fs field: ${name}`);
    return Number(match[1]);
  };
  const sb = {
    blockCount: field("Block count"),
    freeBlocks: field("Free blocks"),
    freeInodes: field("Free inodes"),
    blockSize: field("Block size"),
  };
  assert.equal(sb.blockSize, BLOCK_SIZE, "rootfs block size");
  return sb;
}

// null when absent, otherwise the debugfs inode type ("directory", ...).
function lookup(image, guest, work) {
  const result = command("debugfs", ["-R", `stat ${quote(guest)}`, image], {
    cwd: work,
    env: { ...process.env, TZ: "UTC", LC_ALL: "C" },
  });
  if (/File not found by ext2_lookup/.test(result.stderr)) return null;
  const match = result.stdout.match(/^Inode: \d+\s+Type: (\S+)/m);
  assert(match, `debugfs stat ${guest}:\n${result.stdout}\n${result.stderr}`);
  return match[1];
}

// Read every installed file/symlink back out of the image and compare it with
// the host source. Each entry gets its own numbered destination, so neither a
// case-insensitive build TMPDIR (Darwin) nor read-only store modes interfere.
// Types and modes are checked from the image itself by verifyMetadata.
function verifyContents(image, entries, work) {
  const dumpDir = path.join(work, "dump");
  fs.mkdirSync(dumpDir);
  const commands = [];
  entries.forEach((entry, index) => {
    const dest = path.join(dumpDir, String(index));
    if (entry.type === "file") {
      commands.push(`dump ${quote(entry.guest)} ${quote(dest)}`);
    } else if (entry.type === "symlink") {
      // rdump recreates a symlink as a symlink (dump would read raw blocks).
      fs.mkdirSync(dest);
      commands.push(`rdump ${quote(entry.guest)} ${quote(dest)}`);
    }
  });
  const script = path.join(work, "dump.commands");
  fs.writeFileSync(script, `${commands.join("\n")}\n`);
  const result = command("debugfs", ["-f", script, image], { env: { ...process.env, TZ: "UTC", LC_ALL: "C" } });
  // Build users cannot chown; ownership is checked by verifyMetadata.
  const errors = result.stderr.split("\n").filter((line) =>
    line && !/^debugfs \d/.test(line) && !/Operation not permitted while changing ownership/.test(line));
  assert.deepEqual(errors, [], "debugfs dump diagnostics");
  entries.forEach((entry, index) => {
    const dest = path.join(dumpDir, String(index));
    const label = `installed ${entry.guest}`;
    if (entry.type === "file") {
      assert.equal(sha256(fs.readFileSync(dest)), sha256(fs.readFileSync(entry.host)), `${label}: contents`);
      fs.rmSync(dest);
    } else if (entry.type === "symlink") {
      const link = path.join(dest, path.posix.basename(entry.guest));
      assert(fs.lstatSync(link).isSymbolicLink(), `${label}: type`);
      assert.equal(fs.readlinkSync(link), entry.target, `${label}: target`);
    }
  });
  fs.rmSync(dumpDir, { recursive: true, force: true });
}

// Type, mode, ownership and size of every entry, from the image itself.
function verifyMetadata(image, entries, work) {
  const byParent = new Map();
  for (const entry of entries) {
    const parent = path.posix.dirname(entry.guest);
    if (!byParent.has(parent)) byParent.set(parent, new Map());
    byParent.get(parent).set(path.posix.basename(entry.guest), entry);
  }
  const parents = [...byParent.keys()];
  const out = debugfs(image, parents.map((dir) => `ls -p ${quote(dir)}`), work, false);
  // With -f, debugfs echoes each command before its output.
  const sections = out.split(/^debugfs: ls -p .*$/m).slice(1);
  assert.equal(sections.length, parents.length, "debugfs ls sections");
  parents.forEach((dir, index) => {
    const expected = byParent.get(dir);
    const seen = new Set();
    for (const line of sections[index].split("\n")) {
      // /inode/mode/uid/gid/name/size/  (names cannot contain "/")
      const match = line.match(/^\/(\d+)\/(\d+)\/(\d+)\/(\d+)\/(.*)\/(\d*)\/$/);
      if (!match) continue;
      const entry = expected.get(match[5]);
      if (!entry) continue;
      const label = `installed ${entry.guest}`;
      assert.equal(Number(match[3]), 0, `${label}: uid`);
      assert.equal(Number(match[4]), 0, `${label}: gid`);
      assert.equal(parseInt(match[2], 8), parseInt(entry.mode, 8), `${label}: type/mode`);
      if (entry.type === "file") assert.equal(Number(match[6]), entry.size, `${label}: size`);
      if (entry.type === "symlink") assert.equal(Number(match[6]), Buffer.byteLength(entry.target), `${label}: size`);
      seen.add(match[5]);
    }
    for (const name of expected.keys()) assert(seen.has(name), `installed entry missing: ${dir}/${name}`);
  });
}

export function installGuestTools(image, spec, work) {
  assert.equal(spec.schema, 1, "guest spec schema");
  assert(path.isAbsolute(spec.storeDir), "guest spec storeDir");
  assert(Number.isInteger(spec.headroomMb) && spec.headroomMb >= ROOTFS_HEADROOM_MIN_MB,
    `guest rootfs headroom must be an integer >= ${ROOTFS_HEADROOM_MIN_MB} MB`);

  // The root overlay supplies /nix itself (with an empty nix/store), so all
  // store paths land beneath a directory this step creates.
  const entries = walkTree(spec.root, "/", "root", []).slice(1);
  assert(entries.some((e) => e.guest === "/nix/store" && e.type === "dir"), "guest root must provide /nix/store");
  const storePaths = fs.readFileSync(spec.storePaths, "utf8").split("\n").filter(Boolean).sort();
  assert(storePaths.length > 0, "empty guest closure");
  assert.equal(new Set(storePaths).size, storePaths.length, "duplicate store path");
  for (const storePath of storePaths) {
    assert.equal(path.dirname(storePath), spec.storeDir, `not a top-level store path: ${storePath}`);
    walkTree(storePath, `/nix/store/${path.basename(storePath)}`, "store", entries);
  }

  // Entries may only reuse existing base directories (e.g. /etc,
  // /usr/local/bin); anything else that exists would be clobbered.
  const existing = new Set();
  for (const entry of entries) {
    if (entry.kind !== "root") continue;
    const parentExists = entry.guest.split("/").length === 2 || existing.has(path.posix.dirname(entry.guest));
    if (!parentExists) continue; // beneath a newly created directory
    const type = lookup(image, entry.guest, work);
    if (type === null) continue;
    assert(type === "directory" && entry.type === "dir", `guest tools would replace existing ${type}: ${entry.guest}`);
    existing.add(entry.guest);
  }
  assert(!existing.has("/nix"), "base rootfs already has /nix");
  const created = entries.filter((e) => !existing.has(e.guest));

  // Grow the filesystem: used + new data (+3% for extent/htree overhead) +
  // free space for the guest's own store writes. resize2fs keeps the
  // inodes-per-group ratio, so inode capacity grows with it.
  command("e2fsck", ["-f", "-n", image]);
  const before = superblock(image);
  const needed = created.reduce((sum, e) => sum + entryBlocks(e), 0);
  const target = before.blockCount - before.freeBlocks + Math.ceil(needed * 1.03) +
    Math.ceil((spec.headroomMb * 1024 * 1024) / BLOCK_SIZE);
  if (target > before.blockCount) {
    command("resize2fs", [image, String(target)], {
      env: { ...process.env, E2FSPROGS_FAKE_TIME: "1", TZ: "UTC", LC_ALL: "C" },
    });
  }
  const grown = superblock(image);
  assert(grown.freeInodes > created.length + 1024, `rootfs inodes: need ${created.length}, have ${grown.freeInodes}`);

  const commands = ["set_current_time 1"];
  for (const entry of created) {
    const guest = quote(entry.guest);
    if (entry.type === "dir") commands.push(`mkdir ${guest}`);
    else if (entry.type === "file") commands.push(`write ${quote(entry.host)} ${guest}`);
    else commands.push(`symlink ${guest} ${quote(entry.target)}`);
    // New inodes already get generation 0 and time 1; set_inode_field does
    // not follow a final symlink, so this addresses the link itself.
    commands.push(
      `set_inode_field ${guest} mode ${entry.mode}`,
      `set_inode_field ${guest} uid 0`,
      `set_inode_field ${guest} gid 0`,
    );
  }
  debugfs(image, commands, work, true);
  command("e2fsck", ["-f", "-n", image]);

  verifyMetadata(image, created, work);
  verifyContents(image, created, work);

  const after = superblock(image);
  return {
    storePaths,
    entries: created.length,
    bytes: created.reduce((sum, e) => sum + (e.size ?? 0), 0),
    rootfsBlocks: { before: before.blockCount, after: after.blockCount },
    freeMb: Math.floor((after.freeBlocks * BLOCK_SIZE) / (1024 * 1024)),
  };
}

function replaceHelpers(image, files, checksums, work) {
  // Use controlled relative host paths, avoiding debugfs quoting differences
  // between native Linux and Darwin toolchains or temporary directories.
  for (const name of HELPER_NAMES) {
    const file = path.join(work, name);
    fs.writeFileSync(file, regular(files, `bin/${name}`), { mode: 0o755 });
    fs.utimesSync(file, 1, 1);
  }
  const commands = ["set_current_time 1"];
  for (const name of HELPER_NAMES) {
    const guest = `/usr/bin/${name}`;
    commands.push(`rm ${guest}`, `write ${name} ${guest}`);
    for (const [field, value] of [
      ["mode", "0100755"], ["uid", "0"], ["gid", "0"], ["generation", "0"],
      ["atime", "0x1"], ["ctime", "0x1"], ["mtime", "0x1"], ["crtime", "0x1"],
      ["atime_extra", "0"], ["ctime_extra", "0"], ["mtime_extra", "0"], ["crtime_extra", "0"],
    ]) commands.push(`set_inode_field ${guest} ${field} ${value}`);
  }
  debugfs(image, commands, work, true);
  for (const name of HELPER_NAMES) {
    const dumped = path.join(work, `installed-${name}`);
    const stat = debugfs(image, [`dump /usr/bin/${name} installed-${name}`, `stat /usr/bin/${name}`], work, false);
    assert.equal(sha256(fs.readFileSync(dumped)), checksums[name], `installed helper checksum: ${name}`);
    assert.match(stat, /Type:\s+regular\s+Mode:\s+0755/, `installed helper mode: ${name}`);
    assert.match(stat, /User:\s+0\s+Group:\s+0/, `installed helper ownership: ${name}`);
  }
  command("e2fsck", ["-f", "-n", image]);
}

export async function composeImage({ sdk, inputs, arch, baseArchive, helperArchive, out, guestSpec = null }) {
  assert.equal(inputs.schema, 1, "input pin schema");
  assert(arch === "x86_64" || arch === "aarch64", `unsupported guest architecture: ${arch}`);
  assert.equal(json(path.join(sdk, "package.json")).version, inputs.sdkVersion, "SDK version");
  const load = (file) => import(pathToFileURL(path.join(sdk, "dist/src", file)).href);
  const [{ computeAssetBuildId }, { computeFileHash }, helpers, tar] = await Promise.all([
    load("assets.js"), load("build/helpers.js"), load("build/sandbox-helpers.js"), load("alpine/tar.js"),
  ]);
  assert.deepEqual(helpers.SANDBOX_HELPER_BINARY_NAMES, HELPER_NAMES, "SDK helper inventory");
  const pins = inputs.architectures[arch];
  const base = await readArchive(baseArchive, pins.base, tar, computeFileHash);
  const bundle = await readArchive(helperArchive, pins.helpers, tar, computeFileHash);
  const original = JSON.parse(regular(base, "manifest.json"));
  const helperManifest = JSON.parse(regular(bundle, "manifest.json"));
  assert.equal(original.version, 1, "base manifest version");
  assert.equal(original.config.arch, arch, "base architecture");
  assert.equal(original.config.imageName, inputs.baseName, "base image name");
  sameKeys(original.checksums, Object.keys(original.assets), "base checksum inventory");
  for (const required of ["kernel", "initramfs", "rootfs"]) assert(original.assets[required], `base asset: ${required}`);
  for (const [key, name] of Object.entries(original.assets)) {
    assert(ASSET_NAMES.includes(key), `unknown base asset: ${key}`);
    assert.match(name, /^[A-Za-z0-9_-][A-Za-z0-9_.-]*$/, "asset must be a plain filename");
    assert(name !== "manifest.json" && name !== "provenance.json", "reserved asset filename");
    hashString(original.checksums[key]);
    assert.equal(sha256(regular(base, name)), original.checksums[key], `base checksum: ${key}`);
  }
  assert.equal(new Set(Object.values(original.assets)).size, Object.keys(original.assets).length, "duplicate asset filename");
  inventory(base, ["manifest.json", ...Object.values(original.assets)]);
  inventory(bundle, ["manifest.json", ...HELPER_NAMES.map((name) => `bin/${name}`)], ["bin"]);
  assert.equal(computeAssetBuildId({ checksums: original.checksums, arch }), pins.base.buildId, "base computed buildId");
  assert.equal(original.buildId, pins.base.buildId, "base manifest buildId");
  validateHelperManifest(helperManifest, bundle, arch, pins.helpers, inputs.sdkVersion, helpers.computeSandboxHelperBuildId);

  fs.mkdirSync(out, { recursive: true });
  for (const name of Object.values(original.assets)) fs.writeFileSync(path.join(out, name), regular(base, name));
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "gondolin-image-"));
  const previousCwd = process.cwd();
  let guest = null;
  try {
    process.chdir(work);
    replaceHelpers(path.join(out, original.assets.rootfs), bundle, helperManifest.checksums, work);
    if (guestSpec) {
      guest = installGuestTools(path.join(out, original.assets.rootfs), guestSpec, work);
    }
  } finally {
    process.chdir(previousCwd);
    fs.rmSync(work, { recursive: true, force: true });
  }
  const checksums = Object.fromEntries(Object.entries(original.assets).map(([key, name]) =>
    [key, computeFileHash(path.join(out, name))]));
  const buildId = computeAssetBuildId({ checksums, arch });
  assert.notEqual(buildId, original.buildId, "composition must change image buildId");
  const manifest = {
    ...original,
    // No wall-clock build timestamps; the SDK build ID depends on bytes/arch.
    buildTime: "1970-01-01T00:00:01.000Z",
    checksums,
    buildId,
    runtimeDefaults: { ...original.runtimeDefaults, rootfsMode: "cow" },
  };
  writeJson(path.join(out, "manifest.json"), manifest);
  writeJson(path.join(out, "provenance.json"), {
    schema: 1,
    sdkVersion: inputs.sdkVersion,
    sdkStorePath: sdk,
    sdkRevision: inputs.sdkRevision,
    securityPatches: inputs.securityPatches,
    registryRevision: inputs.registryRevision,
    arch,
    base: { name: inputs.baseName, version: inputs.baseVersion, ...pins.base, checksums: original.checksums },
    helpers: { ...pins.helpers, manifest: helperManifest },
    composition: "replace /usr/bin/{sandboxd,sandboxfs,sandboxssh,sandboxingress} using host debugfs; " +
      (guest ? "grow rootfs and add guest tools (Nix closure + root overlay) using host debugfs; " : "") +
      "base kernel/initramfs unchanged",
    ...(guest ? { guest: { tools: guestSpec.tools, root: guestSpec.root, headroomMb: guestSpec.headroomMb, ...guest } } : {}),
    buildId,
    checksums,
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const [sdk, inputsFile, arch, baseArchive, helperArchive, output, guestSpecFile] = process.argv.slice(2);
  assert(output, "usage: image-manifest.mjs SDK INPUTS_JSON ARCH BASE_TGZ HELPERS_TGZ OUTPUT [GUEST_SPEC_JSON]");
  await composeImage({
    sdk, inputs: json(inputsFile), arch, baseArchive, helperArchive, out: path.resolve(output),
    guestSpec: guestSpecFile ? json(guestSpecFile) : null,
  });
}

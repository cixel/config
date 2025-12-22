// Exercise the same validator used by the image build against both actual,
// fixed-output-fetched release bundles. No guest execution or e2fsprogs needed.
//
// node image-test.mjs SDK INPUTS_JSON X86_HELPERS_TGZ AARCH64_HELPERS_TGZ [IMAGE_MANIFEST_MJS]
// Nix callers should pass IMAGE_MANIFEST_MJS explicitly: independently copied
// source files do not retain their original sibling paths in the store.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { describe, test } from "node:test";
import { pathToFileURL } from "node:url";

const [sdkArg, inputsFile, x86Archive, armArchive, manifestScript = path.join(import.meta.dirname, "image-manifest.mjs")] =
  process.argv.slice(2);
assert(armArchive, "usage: image-test.mjs SDK INPUTS_JSON X86_HELPERS_TGZ AARCH64_HELPERS_TGZ [IMAGE_MANIFEST_MJS]");
const sdk = path.resolve(sdkArg);
const load = (file) => import(pathToFileURL(path.resolve(file)).href);
const [{ validateHelperManifest }, { parseTar, decompressTarGz }, { computeFileHash }, helpers] =
  await Promise.all([
    load(manifestScript),
    load(path.join(sdk, "dist/src/alpine/tar.js")),
    load(path.join(sdk, "dist/src/build/helpers.js")),
    load(path.join(sdk, "dist/src/build/sandbox-helpers.js")),
  ]);
const inputs = JSON.parse(fs.readFileSync(inputsFile, "utf8"));
assert.equal(inputs.schema, 1, "input pin schema");
assert.equal(JSON.parse(fs.readFileSync(path.join(sdk, "package.json"), "utf8")).version,
  inputs.sdkVersion, "test SDK must match pinned SDK");
const names = ["sandboxd", "sandboxfs", "sandboxssh", "sandboxingress"];
assert.deepEqual(helpers.SANDBOX_HELPER_BINARY_NAMES, names, "SDK helper inventory");

for (const [arch, archive] of [["x86_64", x86Archive], ["aarch64", armArchive]]) {
  const pin = inputs.architectures[arch].helpers;
  assert.equal(computeFileHash(archive), pin.sha256, `${arch} test archive must match pin`);
  const files = new Map(parseTar(await decompressTarGz(archive)).map((entry) => [entry.name, entry]));
  const manifest = JSON.parse(files.get("manifest.json").content);
  const validate = (candidate = manifest, candidateFiles = files) =>
    validateHelperManifest(candidate, candidateFiles, arch, pin, inputs.sdkVersion, helpers.computeSandboxHelperBuildId);

  describe(`${arch} official pinned helper bundle`, () => {
    test("accepts the unmodified release manifest and all four binaries", () => validate());

    for (const [field, value, error] of [
      ["schema", 2, /helper manifest schema/],
      ["kind", "wrong-kind", /helper manifest kind/],
      ["gondolinVersion", "0.12.0", /SDK\/helper version mismatch/],
      ["arch", arch === "x86_64" ? "aarch64" : "x86_64", /helper architecture/],
      ["target", "wrong-target", /helper target/],
      ["zigVersion", "wrong-version", /helper Zig version/],
    ]) {
      test(`rejects mismatched ${field}`, () => {
        assert.throws(() => validate({ ...manifest, [field]: value }), error);
      });
    }

    test("rejects missing helper checksum", () => {
      const candidate = structuredClone(manifest);
      delete candidate.checksums.sandboxssh;
      assert.throws(() => validate(candidate), /helper checksum inventory/);
    });
    test("rejects extra helper checksum", () => {
      const candidate = structuredClone(manifest);
      candidate.checksums.extra = "0".repeat(64);
      assert.throws(() => validate(candidate), /helper checksum inventory/);
    });

    for (const name of names) {
      test(`rejects corrupted ${name} bytes`, () => {
        const candidateFiles = new Map(files);
        const entry = { ...files.get(`bin/${name}`) };
        entry.content = Buffer.from(entry.content);
        entry.content[entry.content.length - 1] ^= 1;
        candidateFiles.set(`bin/${name}`, entry);
        assert.throws(() => validate(manifest, candidateFiles), new RegExp(`helper checksum: ${name}`));
      });
      test(`rejects wrong ${name} ELF machine even with matching checksum`, () => {
        const candidateFiles = new Map(files);
        const entry = { ...files.get(`bin/${name}`) };
        entry.content = Buffer.from(entry.content);
        entry.content.writeUInt16LE(0, 18);
        candidateFiles.set(`bin/${name}`, entry);
        const candidate = structuredClone(manifest);
        candidate.checksums[name] = createHash("sha256").update(entry.content).digest("hex");
        assert.throws(() => validate(candidate, candidateFiles), new RegExp(`helper ELF architecture: ${name}`));
      });
    }
  });
}

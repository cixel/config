{ pkgs, lib }:

# Packaging for a complex pi plugin under the `programs.pi.plugins`
# API. Imported from home.nix (see Wire-up site below) and also doubles
# as an exemplar of the npm-deps + CLI-shipping plugin pattern.
#
# Subject: `context-mode` (https://pi.dev/packages/context-mode,
# https://github.com/mksglu/context-mode). It exercises everything our
# plugin module needs to handle:
#
#   * Multi-resource: an extension + a skills directory.
#   * A `pi` manifest in package.json (`./build/adapters/pi/extension.js`,
#     `./skills`), so pi-convention dir layout is NOT enough on its own.
#   * Runtime npm dependencies (8 packages, no peers).
#   * A `context-mode` CLI bin that hooks shell out to.
#
# Strategy:
#
#   1. `buildNpmPackage` with `src` = the upstream tarball (or
#      fetchFromGitHub for a specific tag). This replaces pi's runtime
#      `npm install` with a reproducible, nix-pinned tree.
#
#   2. Point `mkPiPlugin` at `$out/lib/node_modules/context-mode/`
#      (where `buildNpmPackage` puts the package contents). Pi reads
#      the `pi` manifest from the package.json there.
#
#   3. Add the buildNpmPackage derivation itself to `extraPackages`
#      so its `bin/context-mode` lands on PATH.
#
# Hashes are placeholders. On first build, nix will report the real
# values; replace `lib.fakeHash` with what it printed.
#
# Wire-up site (in home.nix):
#
#   let
#     piPlugins  = import ./agents/pi/plugins.nix         { inherit pkgs lib; };
#     ctxModePlg = import ./agents/pi/npm-plugins/context-mode.nix
#                    { inherit pkgs lib; };
#   in {
#     programs.pi.plugins = [
#       (piPlugins.mkPiPluginFromFile { ... modal-editor ... })
#       ctxModePlg
#     ];
#   }

let
  version = "1.0.146";

  # Fetch the published npm tarball. buildNpmPackage will unpack it
  # and run `npm install --omit=dev` against the pinned npmDepsHash.
  # If you prefer the github source, swap to pkgs.fetchFromGitHub and
  # set dontNpmBuild = false to run the TypeScript build step.
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/context-mode/-/context-mode-${version}.tgz";
    hash = "sha256-9NRGw70ROzXFa17ZDb30C+PHlHw17lBei+oU26ZqwAk=";
  };

  # `package-lock.json` and `package.json` vendored from a one-shot
  # local `npm install --package-lock-only` against the npm tarball.
  # Upstream only ships `bun.lock`, which buildNpmPackage doesn't
  # understand. Regenerate both files when bumping `version`.
  npmRoot = ./context-mode;

  context-mode = pkgs.buildNpmPackage {
    pname = "context-mode";
    inherit version src;

    # The npm-published tarball already contains the compiled
    # `build/` and bundle artifacts; no TypeScript build step needed.
    dontNpmBuild = true;

    # Skip lifecycle scripts. `better-sqlite3`'s postinstall would
    # invoke node-gyp and download a SQLite tarball at install time,
    # which is neither pure nor compatible with this work machine's
    # cert MITM. The pi extension itself (./build/adapters/pi/
    # extension.js) doesn't need better-sqlite3 at load time. The
    # `context-mode` CLI does, so the CLI bin will fail until
    # better-sqlite3 is wired in as a separate nix derivation. The
    # extension half of this plugin works regardless.
    npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];

    # Drop in our vendored lockfile before any npm-* hook runs.
    postPatch = ''
      cp ${npmRoot}/package-lock.json package-lock.json
    '';

    # Bypass `fetchNpmDeps` / `prefetch-npm-deps` (Rust/reqwest,
    # doesn't honor the daemon's NIX_SSL_CERT_FILE on this machine).
    # `importNpmLock` translates each lockfile entry into a
    # `pkgs.fetchurl` call, which uses libcurl and inherits the
    # daemon's cert trust like any other FOD.
    npmDeps        = pkgs.importNpmLock { inherit npmRoot; };
    npmConfigHook  = pkgs.importNpmLock.npmConfigHook;

    # buildNpmPackage's default installPhase puts the package at
    # $out/lib/node_modules/<name>/ and links any bin entries from
    # package.json into $out/bin. That's exactly the layout we want.
  };

  piPlugins = import ../plugins.nix { inherit pkgs lib; };
in
{
  package = piPlugins.mkPiPlugin {
    name = "context-mode";
    # The directory containing package.json (and its `pi` manifest).
    # buildNpmPackage places the resolved tree here, including
    # node_modules/ with all 8 runtime deps already installed.
    src = "${context-mode}/lib/node_modules/context-mode";
  };

  # Exposes `context-mode` and `bun` on pi's PATH so hooks
  # registered by the extension can invoke the CLI, and the
  # context-mode runtime can pick up bun for its documented 3-5x
  # speedup over plain node. Scoped to pi (and its subprocesses)
  # via the symlinkJoin wrapper in `pi.nix`, NOT the user's global
  # PATH. To run `context-mode` standalone outside pi, install it
  # explicitly via `home.packages` (or invoke it through pi).
  extraPackages = [ context-mode pkgs.bun ];
}

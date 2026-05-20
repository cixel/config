{ pkgs, lib }:

# Packaging for two skills from https://github.com/badlogic/pi-skills:
# `brave-search` and `browser-tools`. Both ship npm dependencies that
# pi expects to find vendored in `node_modules/` next to their helper
# `.js` scripts at runtime (SKILL.md invokes `{baseDir}/<script>.js`
# via node). Each subskill is built with `buildNpmPackage`, then the
# two results are assembled into a single pi plugin laid out as:
#
#   $out/
#     skills/
#       brave-search/
#         SKILL.md
#         search.js, content.js
#         package.json, package-lock.json
#         node_modules/...
#       browser-tools/
#         SKILL.md
#         browser-*.js
#         package.json, package-lock.json
#         node_modules/...
#
# Pi discovers both via the `skills/` convention dir (no `pi`
# manifest required in $out/package.json).
#
# Lifecycle scripts are disabled (`--ignore-scripts`):
#
#   * `puppeteer`'s postinstall normally downloads a managed Chromium
#     build. The skill uses `puppeteer-core` to attach to an
#     externally-launched Chrome at `127.0.0.1:9222`, so the bundled
#     Chromium isn't needed. Skipping the download keeps the build
#     pure and avoids the unmanaged ~200MB blob.
#
#   * `brave-search` has no postinstall scripts.
#
# `nodejs` is added to `extraPackages` so pi (and only pi, via the
# wrapper in pi.nix) can invoke `node {baseDir}/search.js ...` and
# the various `node {baseDir}/browser-*.js ...` entry points.
#
# Chrome itself is NOT bundled. `browser-tools` needs a Chrome /
# Chromium / Brave binary on the user's system, launched separately
# with `--remote-debugging-port=9222`. The SKILL.md walks pi through
# starting it via `browser-start.js`.
#
# Bumping the pin:
#
#   1. Update `rev` to the new commit sha.
#   2. Recompute `hash` with
#        nix-prefetch-url --unpack \
#          https://github.com/badlogic/pi-skills/archive/<rev>.tar.gz
#      then convert with `nix hash convert --to sri sha256-...`.
#   3. `hms` will surface any npmDepsHash mismatches from
#      `importNpmLock`; those are derived from each subskill's
#      upstream `package-lock.json` so they shouldn't drift unless
#      the lockfile changed.

let
  src = pkgs.fetchFromGitHub {
    owner = "badlogic";
    repo  = "pi-skills";
    rev   = "75d32a382b0c8aafce356d68e17d2dc94c0c953b";
    hash  = "sha256-muBtAiAiLmsh2bd05YvRmyGkJcBs0qBuqATDVenk7ms=";
  };

  # Build one subskill (a single subdirectory of the pi-skills repo
  # that owns its own package.json + package-lock.json). The output
  # is a directory containing the subskill's tree with node_modules/
  # already resolved.
  mkSubskill = name: pkgs.buildNpmPackage {
    pname   = "pi-skill-${name}";
    version = "75d32a3";
    inherit src;

    # buildNpmPackage runs npm in $sourceRoot. Setting it to the
    # subdir scopes the install to that subskill's package.json /
    # package-lock.json, ignoring the rest of the repo.
    sourceRoot = "${src.name}/${name}";

    # The subskills are plain .js + SKILL.md; nothing to compile.
    dontNpmBuild = true;

    # `--ignore-scripts`: skip puppeteer's Chromium download (see
    # header) and any other lifecycle scripts. `--legacy-peer-deps`
    # mirrors the upstream context-mode plugin's tolerance for the
    # ad-hoc peer-dep graphs that show up in JS skill tooling.
    npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];

    # Bypass `fetchNpmDeps` (Rust/reqwest, ignores
    # NIX_SSL_CERT_FILE on work cert-MITM machines).
    # `importNpmLock` translates each lockfile entry into a
    # `pkgs.fetchurl` call, which uses libcurl and inherits the
    # daemon's cert trust like any other FOD.
    #
    # Eval-time read of the lockfile through a fetchFromGitHub
    # output is fine: the fetch is a fixed-output derivation, so
    # its store path is determined by `hash` and realised without
    # IFD penalty.
    npmDeps       = pkgs.importNpmLock { npmRoot = "${src}/${name}"; };
    npmConfigHook = pkgs.importNpmLock.npmConfigHook;

    # Default installPhase from buildNpmPackage puts things under
    # $out/lib/node_modules/<pkgname>/, which isn't useful for our
    # pi-skill layout. Override to copy the resolved tree (incl.
    # node_modules/) straight to $out.
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -RL . $out/
      runHook postInstall
    '';
  };

  brave   = mkSubskill "brave-search";
  browser = mkSubskill "browser-tools";

  # Assemble both subskills into a single pi plugin package. Pi
  # auto-discovers skills under `$out/skills/<name>/` when the
  # plugin's package.json (if any) has no `pi` manifest.
  pi-skills-pack = pkgs.runCommandLocal "pi-skills-pack" {
    passthru = { piPlugin = true; };
  } ''
    mkdir -p $out/skills
    cp -RL ${brave}   $out/skills/brave-search
    cp -RL ${browser} $out/skills/browser-tools
    chmod -R u+w $out
  '';
in
{
  package = pi-skills-pack;

  # `node` so pi can run `{baseDir}/search.js`, `{baseDir}/browser-
  # start.js`, etc. Scoped to pi (and its subprocesses) via the
  # symlinkJoin wrapper in `pi.nix`, NOT the user's global PATH.
  extraPackages = [ pkgs.nodejs ];
}

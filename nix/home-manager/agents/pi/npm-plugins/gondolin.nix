{
  pkgs,
  lib,
  # Function from the guest's Linux package set to packages whose bin/ is
  # baked into the VM image (/nix/store + /usr/local/bin). See image.nix.
  guestTools ? (_: [ ]),
}:

# Upstream ships its Pi extension as an example, not in the npm package.
# Fetch it from the same release as the SDK and keep node_modules next to
# it so Pi can resolve @earendil-works/gondolin without a runtime install.
let
  npmRoot = ./gondolin;
  version = (lib.importJSON (npmRoot + "/package.json")).version;
  guestImage = import ./gondolin/image.nix {
    inherit pkgs lib guestTools;
    sdk = gondolinSdk;
  };
  helperArchiveFor = guestArch: (import ./gondolin/image.nix {
    inherit pkgs lib guestArch;
    sdk = gondolinSdk;
  }).helperArchive;

  extension = pkgs.fetchurl {
    # v0.13.0, matching the SDK version in gondolin/package{,-lock}.json.
    url = "https://raw.githubusercontent.com/earendil-works/gondolin/fcbcef162a73b214f79069f8430c70cebda0f827/host/examples/pi-gondolin.ts";
    hash = "sha256-fPtViAGPlT43BFDXaRb9R+83Qhg5LZ6yo67MRR+87ls=";
  };

  # The published SDK tarball, with reviewed upstream fixes backported onto
  # the pinned 0.13.0 release (no newer release contains them):
  #
  #   0001: 02ab792 — serialize fs-rpc request handling, closing a
  #     RealFSProvider path-validation TOCTOU that let a pipelining guest
  #     swap directories between check and use (mount-root escape).
  #   0002: 0705083 (host side) — forward guest chmod to VFS providers;
  #     RealFSProvider masks off setuid/setgid bits. The guest-side part
  #     (sandboxfs sending the chmod op) only matters once we build a
  #     custom image; a stock 0.13.0 guest simply never sends it.
  #
  # Verified against upstream commit diffs; regression tests live in
  # gondolin/test/sdk-backports.test.ts and run in tests.sdk-backports.
  gondolinSdk = pkgs.stdenvNoCC.mkDerivation {
    pname = "gondolin-sdk";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/gondolin/-/gondolin-${version}.tgz";
      hash = "sha256-EQSEIvRnLTMGzN+Xvq/Z2VIW35363HduMK+X0MT9AdE=";
    };
    patches = [
      ./gondolin/sdk-patches/0001-fsrpc-serialize.patch
      ./gondolin/sdk-patches/0002-chmod-forwarding.patch
    ];
    doCheck = true;
    nativeCheckInputs = [ pkgs.nodejs_22 ];
    checkPhase = ''
      for f in $(find dist -name '*.js'); do
        node --check "$f"
      done
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -RL . $out/
      runHook postInstall
    '';
  };

  gondolin = pkgs.buildNpmPackage {
    pname = "pi-gondolin";
    inherit version;
    src = lib.fileset.toSource {
      root = npmRoot;
      fileset = lib.fileset.unions [
        (npmRoot + "/package.json")
        (npmRoot + "/package-lock.json")
      ];
    };

    # The published SDK is already compiled; Pi loads the TS extension.
    dontNpmBuild = true;

    # Use the portable QEMU backend, not platform-specific krun binaries.
    # ssh2 also works without its optional native acceleration, so no
    # lifecycle scripts or node-gyp downloads are needed.
    npmFlags = [ "--ignore-scripts" "--omit=optional" ];

    # Match the other plugins: fetch dependencies through libcurl-backed
    # Nix fetchers, which respect the work machines' certificate trust.
    npmDeps = pkgs.importNpmLock { inherit npmRoot; };
    npmConfigHook = pkgs.importNpmLock.npmConfigHook;

    prePatch = ''
      install -Dm644 ${extension} extensions/pi-gondolin.ts
    '';

    # Accept the /workspace paths advertised in the system prompt and
    # keep user ! commands from falling back to the host if startup fails.
    patches = [ ./gondolin/pi-extension.patch ];
    patchFlags = [ "-p1" "--fuzz=0" ];
    postPatch = ''
      substituteInPlace extensions/pi-gondolin.ts \
        --replace-fail '@gondolinGuestImage@' '${guestImage}'
    '';

    # Replace the pristine SDK from the npm lock with our patched build
    # (same tarball + backported fixes). Runs after npmConfigHook has
    # linked node_modules, before the (disabled) npm build.
    preBuild = ''
      rm -rf node_modules/@earendil-works/gondolin
      cp -r ${gondolinSdk} node_modules/@earendil-works/gondolin
      chmod -R u+w node_modules/@earendil-works/gondolin
    '';

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      node --experimental-vm-modules ${./gondolin/tests}/extension.mjs "$PWD" '${guestImage}'
      runHook postCheck
    '';

    # Keep the Pi manifest, extension and runtime dependencies together.
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -RL . $out/
      runHook postInstall
    '';

    passthru.tests = {
      # Keep security coverage without pulling in the separate lifecycle work.
      sdk-backports =
        pkgs.runCommand "pi-gondolin-sdk-backport-tests"
          {
            nativeBuildInputs = [ pkgs.nodejs_22 ];
          }
          ''
            cp -r ${./gondolin/test} test
            cp ${./gondolin/package.json} package.json
            chmod -R u+w test
            export TMPDIR="$PWD/tmp"
            mkdir -p tmp
            export PI_GONDOLIN_SDK_DIR=${gondolin}/node_modules/@earendil-works/gondolin
            node --experimental-strip-types --no-warnings --test test/*.test.ts
            touch $out
          '';
    };
  };

  piPlugins = import ../plugins.nix { inherit pkgs lib; };
  resumeTest = pkgs.writeShellApplication {
    name = "pi-gondolin-resume-test";
    runtimeInputs = [ pkgs.nodejs pkgs.qemu ];
    text = ''
      exec node --experimental-vm-modules ${./gondolin/tests}/idle-resume.mjs ${gondolin} '${guestImage}' "$@"
    '';
  };
  tests = gondolin.passthru.tests // {
    helpers = pkgs.runCommand "pi-gondolin-helper-contract-tests" {
      nativeBuildInputs = [ pkgs.nodejs_22 ];
    } ''
      node ${./gondolin/image-test.mjs} ${gondolinSdk} ${./gondolin/image-inputs.json} \
        ${helperArchiveFor "x86_64"} ${helperArchiveFor "aarch64"} ${./gondolin/image-manifest.mjs}
      touch $out
    '';
    extension = pkgs.runCommand "pi-gondolin-packaged-extension-tests" {
      nativeBuildInputs = [ pkgs.nodejs ];
    } ''
      node --experimental-vm-modules ${./gondolin/tests}/extension.mjs ${gondolin} '${guestImage}'
      touch $out
    '';
  };
in
assert lib.assertMsg
  ((lib.importJSON (npmRoot + "/package.json")).dependencies."@earendil-works/gondolin" == version)
  "Gondolin SDK and extension must be updated together";
{
  package = (piPlugins.mkPiPlugin {
    name = "gondolin";
    src = gondolin;
  }).overrideAttrs (old: {
    passthru = (old.passthru or {}) // {
      inherit guestImage resumeTest tests;
    };
  });

  # Scoped to Pi's wrapper, not the user's global PATH. The image is in
  # the extension's Nix closure; no first-use registry or cache lookup.
  extraPackages = [ pkgs.qemu ];
}

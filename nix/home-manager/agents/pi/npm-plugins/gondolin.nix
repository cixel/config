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

  extension = pkgs.fetchurl {
    # v0.13.0, matching the SDK version in gondolin/package{,-lock}.json.
    url = "https://raw.githubusercontent.com/earendil-works/gondolin/fcbcef162a73b214f79069f8430c70cebda0f827/host/examples/pi-gondolin.ts";
    hash = "sha256-fPtViAGPlT43BFDXaRb9R+83Qhg5LZ6yo67MRR+87ls=";
  };

  gondolin = pkgs.buildNpmPackage {
    pname = "pi-gondolin";
    inherit version;
    src = npmRoot;

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

    # Keep the Pi manifest, extension and runtime dependencies together.
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -RL . $out/
      runHook postInstall
    '';
  };

  piPlugins = import ../plugins.nix { inherit pkgs lib; };
in
{
  package = piPlugins.mkPiPlugin {
    name = "gondolin";
    src = gondolin;
  };

  # Scoped to Pi's wrapper, not the user's global PATH. Guest images are
  # downloaded by Gondolin on first use and cached in the user's home.
  extraPackages = [ pkgs.qemu ];
}

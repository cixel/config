{
  pkgs,
  lib ? pkgs.lib,
  sdk,
  guestArch ? pkgs.stdenv.hostPlatform.parsed.cpu.name,
  # Function from the guest's Linux package set to a list of packages to bake
  # into the image. Their closure goes into /nix/store (registered in a Nix
  # DB so the guest's own `nix` treats it as valid) and their bin/ entries
  # are linked from /usr/local/bin, which is on the guest's default PATH.
  guestTools ? (_: [ ]),
  # Free space left in the rootfs for the guest's own writes (e.g. `nix
  # build` results in /nix/store). With rootfs mode "cow" these land in a
  # per-VM overlay, but the filesystem size still caps them. The image is
  # not sparse in the Nix store, so this costs host disk once per image.
  guestHeadroomMb ? 1024,
}:

# Compose release artifacts using native host tools, including on Darwin.
# Nothing here executes guest binaries, mounts ext4, downloads during the
# ordinary build, or consults Gondolin's mutable per-user image/helper cache.
# Guest tools are ordinary Linux derivations (built by a Linux builder on
# Darwin hosts); the host only copies their store paths into the ext4 image.
let
  inputPins = lib.importJSON ./image-inputs.json;
  pins =
    inputPins.architectures.${guestArch}
      or (throw "Gondolin guest images support only x86_64 and aarch64 (got ${guestArch})");
  lock = lib.importJSON ./package-lock.json;
  sdkLock = lock.packages."node_modules/@earendil-works/gondolin";
  fetchArchive =
    name: pin:
    pkgs.fetchurl {
      inherit name;
      inherit (pin) url;
      sha256 = pin.sha256;
    };
  baseArchive = fetchArchive "gondolin-alpine-base-${inputPins.baseVersion}-${guestArch}.tar.gz" pins.base;
  helperArchive = fetchArchive "gondolin-helpers-${inputPins.sdkVersion}-${guestArch}.tar.gz" pins.helpers;

  # pkgsLinux re-imports this nixpkgs (keeping overlays and config) for the
  # Linux flavour of the host CPU; on Linux hosts it is pkgs itself. Other
  # guest architectures would need a cross/remote package set; only the
  # helper-contract tests use them, and they never force this.
  hostCpu = pkgs.stdenv.hostPlatform.parsed.cpu.name;
  guestPkgs =
    if guestArch == hostCpu then
      pkgs.pkgsLinux
    else
      throw "Gondolin guest tools for ${guestArch} need a ${guestArch}-linux package set (host CPU is ${hostCpu})";
  toolPackages = guestTools guestPkgs;
  withTools = toolPackages != [ ];

  toolsEnv = guestPkgs.buildEnv {
    name = "pi-gondolin-guest-tools";
    paths = toolPackages;
    pathsToLink = [ "/bin" ];
  };
  toolsClosure = guestPkgs.closureInfo { rootPaths = [ toolsEnv ]; };

  # Everything outside /nix/store that the guest needs. Copied over the base
  # rootfs; the composer refuses to replace anything but existing directories.
  guestRoot =
    guestPkgs.runCommand "pi-gondolin-guest-root"
      {
        nativeBuildInputs = [
          guestPkgs.nix
          guestPkgs.sqlite
        ];
      }
      ''
        mkdir -p $out/etc/nix $out/usr/local/bin $out/nix/store $out/nix/var/nix/gcroots

        # Register the closure the way dockerTools' mkDbExtraCommand does, so
        # the guest's nix sees these paths as valid instead of refetching.
        export NIX_REMOTE="local?root=$PWD/db-root" USER=nobody HOME=$PWD NIX_CONF_DIR=$PWD
        nix-store --load-db < ${toolsClosure}/registration
        db=db-root/nix/var/nix/db
        sqlite3 $db/db.sqlite "UPDATE ValidPaths SET registrationTime = 1"
        # big-lock/reserved are recreated at runtime; ship only the state.
        test ! -e $db/db.sqlite-wal
        mkdir $out/nix/var/nix/db
        cp $db/db.sqlite $db/schema $out/nix/var/nix/db/

        # Keep the tools alive across `nix-collect-garbage` in the guest.
        ln -s ${toolsEnv} $out/nix/var/nix/gcroots/pi-gondolin-guest-tools

        for bin in ${toolsEnv}/bin/*; do
          ln -s "$bin" "$out/usr/local/bin/$(basename "$bin")"
        done

        # Single-user root store in a disposable VM: there are no nixbld
        # users, and the VM itself is the sandbox.
        cat > $out/etc/nix/nix.conf <<'EOF'
        experimental-features = nix-command flakes
        build-users-group =
        sandbox = false
        EOF
      '';

  guestSpec = pkgs.writeText "pi-gondolin-guest-spec.json" (
    builtins.toJSON {
      schema = 1;
      inherit (builtins) storeDir;
      root = guestRoot;
      storePaths = "${toolsClosure}/store-paths";
      headroomMb = guestHeadroomMb;
      env = toolsEnv;
      tools = map (p: {
        name = lib.getName p;
        version = lib.getVersion p;
        path = p;
      }) toolPackages;
    }
  );

  guestImage = pkgs.stdenvNoCC.mkDerivation (
    {
      pname = "pi-gondolin-guest-image-${guestArch}";
      version =
        "${inputPins.baseVersion}-helpers-${inputPins.sdkVersion}" + lib.optionalString withTools "-tools";
      dontUnpack = true;
      nativeBuildInputs = [
        pkgs.nodejs_22
        pkgs.e2fsprogs
        pkgs.coreutils
      ];
      # Epoch 1, not 0: libext2fs treats a zero current-time override as unset.
      E2FSPROGS_FAKE_TIME = "1";
      SOURCE_DATE_EPOCH = "1";
      TZ = "UTC";
      LC_ALL = "C";
      buildPhase = ''
        runHook preBuild
        node ${./image-manifest.mjs} \
          ${sdk} ${./image-inputs.json} ${lib.escapeShellArg guestArch} \
          ${baseArchive} ${helperArchive} "$out" ${lib.optionalString withTools "${guestSpec}"}
        runHook postBuild
      '';
      dontInstall = true;
      dontFixup = true;
      passthru = {
        inherit
          guestArch
          inputPins
          baseArchive
          helperArchive
          sdk
          ;
        provenance = "${guestImage}/provenance.json";
      }
      // lib.optionalAttrs withTools {
        inherit
          guestRoot
          toolsEnv
          toolsClosure
          guestSpec
          ;
      };
      meta = {
        description = "Pinned Alpine Gondolin image with matching official SDK guest helpers";
        platforms = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];
      };
    }
    # Never rewrite guest ELF files or scan their foreign references.
    # provenance.json identifies the exact patched SDK compatibility unit.
    # With guest tools, the uncompressed ext4 necessarily mentions (and so
    # references) every closure path; keeping them alive is intended.
    // lib.optionalAttrs (!withTools) {
      allowedReferences = [ sdk ];
    }
  );
in
assert sdkLock.version == inputPins.sdkVersion;
assert pins.helpers.gondolinVersion == inputPins.sdkVersion;
guestImage

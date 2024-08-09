# creates a NixOS system configuration
{ self, nixpkgs }:

name:
{ system
, user
, darwin ? false
, wsl ? false
  # optional hardware module
, hardware ? { }
}:

let
  systemFunc =
    if darwin
    then self.inputs.darwin.lib.darwinSystem
    else nixpkgs.lib.nixosSystem;
  home-manager =
    if darwin
    then self.inputs.home-manager.darwinModules
    else self.inputs.home-manager.nixosModules;

  pkgs = import nixpkgs {
    inherit system overlays;
  };
  overlays = [
    (self: super: {
      go = super.go.overrideAttrs (old: rec {
        version = "1.22.6";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-nkjZnVGYgleZF9gYnBfpjDc84lq667mHcuKScIiZKlE=";
        };
        patches = [ ] ++ (
          if darwin then [ ../home-manager/fd_fsync_darwin.patch ]
          else [ ]
        );
        GOROOT_BOOTSTRAP = "${super.go}/share/go";
      });

      # https://github.com/NixOS/nixpkgs/issues/154163#issuecomment-1350599022
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  machineConfig = ./machines/${name}.nix;
  darwinConfig = import ./darwin.nix { inherit user; };
  nixosConfig = import ./nixos.nix { inherit user; };
  homeConfig = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.verbose = true;
    home-manager.backupFileExtension = "bak";
    home-manager.users.${user} = import ../home-manager/home.nix {
      inherit darwin wsl;
    };
  };

  baseConfig = { pkgs, ... }:
    {
      # Auto upgrade nix package and the daemon service.
      # services.nix-daemon.enable = true;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      # environment.systemPackages = [ ];

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # TODO: there are settings in old /etc/nix/nix.conf generated by
      # the detsys nix installer which i haven't migrated here yet
      nix.settings.experimental-features = ''
        nix-command flakes
      '';

      fonts.packages = [ pkgs.hack-font ];

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = system;
    };
in
systemFunc {
  inherit system;

  modules = [
    { nixpkgs.overlays = overlays; }

    hardware
    # (if wsl then self.inputs.wsl.nixosModules.wsl else { })
    # (if builtins.isNull then self.inputs.wsl.nixosModules.wsl else { })

    baseConfig
    (if darwin then darwinConfig else nixosConfig)
    machineConfig

    home-manager.home-manager
    homeConfig
  ];
}

{
  # initial flake.nix generated with 'nix flake init -t nix-darwin' with
  # structural changes based on github.com/mitchellh/nixos-config
  description = "asdf";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ... }:
    let
      mkSystem = name:
        { system
        , user
        , darwin ? false
        ,
        }:
        let
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          systemFunc =
            if darwin
            then inputs.darwin.lib.darwinSystem
            else nixpkgs.lib.nixosSystem;
          home-manager =
            if darwin
            then inputs.home-manager.darwinModules
            else inputs.home-manager.nixosModules;

          overlays = [
            (self: super: {
              go = super.go.overrideAttrs (old: rec {
                version = "1.22.2";
                src = pkgs.fetchurl {
                  url = "https://go.dev/dl/go${version}.src.tar.gz";
                  hash = "sha256-N06oKyiexzjpaCZ8rFnH1f8YD5SSJQJUeEsgROkN9ak=";
                };
                patches = [ ] ++ (
                  if darwin then [ ./home-manager/fd_fsync_darwin.patch ]
                  else [ ]
                );
                GOROOT_BOOTSTRAP = "${super.go_1_21}/share/go";
              });
            })
          ];

          machineConfig = ./nix/machines/${name}.nix;
          homeConfig = {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${user} = import ./home-manager/home.nix;
          };

          baseConfig = { pkgs, ... }: {
            # Auto upgrade nix package and the daemon service.
            # services.nix-daemon.enable = true;

            # List packages installed in system profile. To search by name, run:
            # $ nix-env -qaP | grep wget
            environment.systemPackages = [ ];

            # Set Git commit hash for darwin-version.
            system.configurationRevision = self.rev or self.dirtyRev or null;

            # TODO: there are settings in old /etc/nix/nix.conf generated by
            # the detsys nix installer which i haven't migrated here yet
            nix.settings.experimental-features = ''
              nix-command flakes
            '';

            # Used for backwards compatibility, please read the changelog before changing.
            # $ darwin-rebuild changelog
            system.stateVersion = 4;

            # The platform the configuration will be used on.
            nixpkgs.hostPlatform = system;
          };
        in
        systemFunc {
          inherit system;
          modules = [
            { nixpkgs.overlays = overlays; }
            baseConfig
            machineConfig
            (if darwin then import ./nix/darwin.nix { inherit user; } else { })
            home-manager.home-manager
            homeConfig
          ];
        };
    in
    {
      darwinConfigurations."ESINAI-Q6K2T5H20N" = mkSystem "ESINAI-Q6K2T5H20N" {
        system = "aarch64-darwin";
        user = "ehdens";
        darwin = true;
      };

      darwinConfigurations."SADMINISTRATOR-C02X91VSJGH6" = mkSystem "SADMINISTRATOR-C02X91VSJGH6" {
        system = "x86_64-darwin";
        user = "ehdens";
        darwin = true;
      };
    };
}

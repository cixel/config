{
  # initial flake.nix generated with 'nix flake init -t nix-darwin' with
  # structural changes based on github.com/mitchellh/nixos-config
  description = "nixos and nix-darwin configurations";

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
    wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
  };

  outputs = { self, nixpkgs, wsl, hardware, ... }:
    let
      mkSystem = import ./nix/mkSystem.nix {
        inherit self nixpkgs;
      };
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
    {
      darwinConfigurations."ESINAI-Q6K2T5H20N" = mkSystem "ESINAI-Q6K2T5H20N" {
        system = "aarch64-darwin";
        user = "ehdens";
      };

      darwinConfigurations."ESINAI-C02X91VSJGH6" = mkSystem "ESINAI-C02X91VSJGH6" {
        system = "x86_64-darwin";
        user = "ehdens";
      };
      darwinConfigurations."SADMINISTRATOR-C02X91VSJGH6" =
        self.darwinConfigurations."ESINAI-C02X91VSJGH6";

      nixosConfigurations."vm-aarch64" = mkSystem "vm-aarch64" {
        system = "aarch64-linux";
        user = "test";
      };

      darwinConfigurations."alnilam" = mkSystem "alnilam" {
        system = "x86_64-darwin";
        user = "alnilam";
      };

      nixosConfigurations."alnitak-wsl" = mkSystem "alnitak-wsl" {
        system = "x86_64-linux";
        user = "alnitak";
        hardware = wsl.nixosModules.wsl;
      };

      nixosConfigurations."banjo" = mkSystem "banjo" {
        system = "aarch64-linux";
        user = "banjo";
        hardware = hardware.nixosModules.raspberry-pi-4;
      };

      nixosConfigurations."pi0" = mkSystem "pi0" {
        system = "aarch64-linux";
        user = "adblock";
        hardware = hardware.nixosModules.raspberry-pi-4;
      };

      packages = forAllSystems (system:
        let
          cfg = mkSystem "empty" {
            inherit system;
            user = "empty";
          };
        in
        {
          nvim =
            let
              pkg = cfg.config.home-manager.users.empty.programs.neovim;
              lua = cfg.pkgs.writeText "init.lua" ''
                ${pkg.extraLuaConfig}
                ${pkg.generatedConfigs.lua}
              '';
            in
            cfg.pkgs.writeShellScriptBin "nvim" ''
              ${pkg.finalPackage}/bin/nvim -u ${lua} "$@"
           '';
        }
      );
    };
}

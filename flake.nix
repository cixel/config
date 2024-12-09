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
    in
    {
      darwinConfigurations."ESINAI-Q6K2T5H20N" = mkSystem "ESINAI-Q6K2T5H20N" {
        system = "aarch64-darwin";
        user = "ehdens";
        darwin = true;
      };

      darwinConfigurations."ESINAI-C02X91VSJGH6" = mkSystem "ESINAI-C02X91VSJGH6" {
        system = "x86_64-darwin";
        user = "ehdens";
        darwin = true;
      };

      nixosConfigurations."vm-aarch64" = mkSystem "vm-aarch64" {
        system = "aarch64-linux";
        user = "test";
      };

      darwinConfigurations."alnilam" = mkSystem "alnilam" {
        system = "x86_64-darwin";
        user = "ehden";
        darwin = true;
      };

      nixosConfigurations."alnitak-wsl" = mkSystem "alnitak-wsl" {
        system = "x86_64-linux";
        user = "alnitak";
        wsl = true;
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
    };
}

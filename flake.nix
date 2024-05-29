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
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ... }:
    let
      mkSystem = import ./nix/mkSystem.nix {
        inherit self nixpkgs inputs;
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

      nixosConfigurations."vm-aarch64" = mkSystem "vm-aarch64" {
        system = "aarch64-linux";
        user = "test";
      };

      darwinConfigurations."alnilam" = mkSystem "alnilam" {
        system = "x86_64-darwin";
        user = "ehden";
        darwin = true;
      };
    };
}

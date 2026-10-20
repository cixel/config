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
      lib = nixpkgs.lib;

      mkHost = { system, user, modules }:
        let
          darwin = lib.strings.hasSuffix "darwin" system;
          systemFunc = if darwin then self.inputs.darwin.lib.darwinSystem else lib.nixosSystem;
        in
        systemFunc {
          inherit system;
          specialArgs = {
            inherit self system user;
          };
          modules = modules;
        };

      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      hosts = {
        "ESINAI-Q6K2T5H20N" = {
          system = "aarch64-darwin";
          user = "ehdens";
          modules = [
            ./nix/base.nix
            ./nix/darwin.nix
            ./nix/home-manager.nix
            ./nix/work.nix
            ./nix/machines/ESINAI-Q6K2T5H20N.nix
          ];
        };

        "ESINAI-C02X91VSJGH6" = {
          system = "x86_64-darwin";
          user = "ehdens";
          modules = [
            ./nix/base.nix
            ./nix/darwin.nix
            ./nix/home-manager.nix
            ./nix/work.nix
            ./nix/machines/ESINAI-C02X91VSJGH6.nix
          ];
        };

        "vm-aarch64" = {
          system = "aarch64-linux";
          user = "test";
          modules = [
            ./nix/base.nix
            ./nix/nixos.nix
            ./nix/home-manager.nix
            ./nix/machines/vm-aarch64.nix
          ];
        };

        "alnilam" = {
          system = "x86_64-darwin";
          user = "alnilam";
          modules = [
            ./nix/base.nix
            ./nix/darwin.nix
            ./nix/home-manager.nix
            ./nix/machines/alnilam.nix
          ];
        };

        "alnitak-wsl" = {
          system = "x86_64-linux";
          user = "alnitak";
          modules = [
            ./nix/base.nix
            ./nix/nixos.nix
            ./nix/home-manager.nix
            wsl.nixosModules.wsl
            ./nix/machines/alnitak-wsl.nix
          ];
        };

        "banjo" = {
          system = "aarch64-linux";
          user = "banjo";
          modules = [
            ./nix/base.nix
            ./nix/nixos.nix
            ./nix/home-manager.nix
            hardware.nixosModules.raspberry-pi-4
            ./nix/machines/banjo.nix
          ];
        };

        "pi0" = {
          system = "aarch64-linux";
          user = "adblock";
          modules = [
            ./nix/base.nix
            ./nix/nixos.nix
            ./nix/home-manager.nix
            hardware.nixosModules.raspberry-pi-4
            ./nix/machines/pi0.nix
          ];
        };
      };
    in
    {
      darwinConfigurations = {
        "ESINAI-Q6K2T5H20N" = mkHost hosts."ESINAI-Q6K2T5H20N";

        "ESINAI-C02X91VSJGH6" = mkHost hosts."ESINAI-C02X91VSJGH6";
        "SADMINISTRATOR-C02X91VSJGH6" =
          self.darwinConfigurations."ESINAI-C02X91VSJGH6";

        "alnilam" = mkHost hosts."alnilam";
      };

      nixosConfigurations = {
        "vm-aarch64" = mkHost hosts."vm-aarch64";
        "alnitak-wsl" = mkHost hosts."alnitak-wsl";
        "banjo" = mkHost hosts."banjo";
        "pi0" = mkHost hosts."pi0";
      };

      packages = forAllSystems (system:
        let
          cfg = mkHost {
            inherit system;
            user = "empty";
            modules = [
              ./nix/base.nix
              (if lib.strings.hasSuffix "darwin" system then ./nix/darwin.nix else ./nix/nixos.nix)
              ./nix/home-manager.nix
              ./nix/machines/empty.nix
            ];
          };
          gondolin = import ./nix/home-manager/agents/pi/npm-plugins/gondolin.nix {
            pkgs = cfg.pkgs;
            inherit lib;
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
          pi-gondolin = gondolin.package;
          pi-gondolin-image = gondolin.package.guestImage;
          pi-gondolin-sdk-tests = gondolin.package.tests.sdk-backports;
          pi-gondolin-extension-tests = gondolin.package.tests.extension;
          pi-gondolin-helper-tests = gondolin.package.tests.helpers;
          # Hardware access is unavailable inside ordinary Nix build sandboxes.
          pi-gondolin-resume-test = gondolin.package.resumeTest;

          # pi-fence: unit tests (host faked; the pi package import is
          # stubbed) plus a tripwire that the pinned pi still exports the
          # tool factories the extension relies on and still aliases the
          # package specifier for extension imports.
          pi-fence-tests = cfg.pkgs.runCommand "pi-fence-unit-tests"
            { nativeBuildInputs = [ cfg.pkgs.bun ]; }
            ''
              cp -r ${./nix/home-manager/agents/pi} src
              chmod -R u+w src
              cd src
              bun test ./tests/pi-fence.test.ts
              touch $out
            '';
          pi-fence-api-check = cfg.pkgs.runCommand "pi-fence-api-check"
            { nativeBuildInputs = [ cfg.pkgs.nodejs ]; }
            ''
              node --input-type=module -e '
                const m = await import(process.argv[1]);
                for (const k of ["createBashTool", "createLocalBashOperations"])
                  if (typeof m[k] !== "function")
                    throw new Error("pi API drift: " + k + " is " + typeof m[k]);
                console.log("pi extension API OK:", Object.keys(m).length, "exports");
              ' ${cfg.pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/dist/index.js
              grep -q '@earendil-works/pi-coding-agent' \
                ${cfg.pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/dist/core/extensions/loader.js
              touch $out
            '';
          # Hardware boundary test: not a build (needs the real OS sandbox).
          pi-fence-test = cfg.pkgs.writeShellApplication {
            name = "pi-fence-test";
            runtimeInputs = [ cfg.pkgs.bun ];
            text = ''
              export PI_FENCE_BASH="''${PI_FENCE_BASH:-${cfg.pkgs.bash}/bin/bash}"
              ${lib.optionalString cfg.pkgs.stdenv.isLinux ''
                export PI_FENCE_BWRAP="''${PI_FENCE_BWRAP:-${cfg.pkgs.bubblewrap}/bin/bwrap}"
              ''}
              cd ${./nix/home-manager/agents/pi}
              exec bun tests/pi-fence-hardware.mjs "$@"
            '';
          };
        }
      );
    };
}

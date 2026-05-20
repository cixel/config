{ config, lib, pkgs, ... }:

# Custom home-manager module for the `pi` coding agent
# (https://github.com/badlogic/pi-coding-agent).
#
# Pi has no upstream home-manager module, so this manages:
#
#   ~/.pi/agent/settings.json   <- from `programs.pi.settings`
#   ~/.pi/agent/AGENTS.md       <- from `programs.pi.context` (optional)
#
# Skills and extensions are NOT symlinked. Instead, point pi at the
# nix source directory via `settings.skills` and `settings.extensions`,
# which are additive to pi's auto-discovered defaults. That keeps
# `~/.pi/agent/{skills,extensions}/` available as pi's writable
# scratch space while letting `~/.config/nix/home-manager/agents/...`
# serve as the persistent, version-controlled library.
#
# For third-party plugins, use `programs.pi.plugins`. Each entry is a
# nix derivation whose `$out` is a pi-package-shaped directory; see
# `agents/pi/plugins.nix` for the `mkPiPluginFromFile` / `mkPiPlugin`
# helpers. Each plugin's store path is appended to `settings.packages`,
# which pi treats as a local-path package source (no copy, no
# `npm install`, just convention-dir discovery).
#
# Pi's own `npm:` / `git:` package sources are intentionally not used:
# everything pi loads should be reproducible and resolved by nix.
#
# By default this also installs `pkgs.pi-coding-agent`. Override
# `programs.pi.package` to install a different build or to skip the
# install if you manage pi outside of nix.

let
  cfg = config.programs.pi;
  settingsFormat = pkgs.formats.json { };
in
{
  options.programs.pi = {
    enable = lib.mkEnableOption "pi coding agent configuration management";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pi-coding-agent;
      defaultText = lib.literalExpression "pkgs.pi-coding-agent";
      description = ''
        The pi package to install. Set to a no-op derivation (or use
        `home.packages` directly with a different attribute) if you
        install pi outside of nix.
      '';
    };

    context = lib.mkOption {
      type = lib.types.either lib.types.lines lib.types.path;
      default = "";
      example = lib.literalExpression "./agents/context.md";
      description = ''
        Global context for pi. Either inline content as a string, or a
        path to a markdown file. The content is installed at
        `~/.pi/agent/AGENTS.md`, which pi loads on every startup
        regardless of cwd.
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          defaultProvider = "anthropic";
          defaultModel = "claude-opus-4-7";
          defaultThinkingLevel = "high";
          theme = "dark";
          skills     = [ "~/.config/nix/home-manager/agents/skills" ];
          extensions = [ "~/.config/nix/home-manager/agents/pi/extensions" ];
        }
      '';
      description = ''
        Contents of `~/.pi/agent/settings.json`. See pi's settings docs
        for the full schema. `~` and absolute paths are supported in
        the `skills` and `extensions` arrays. Pi will not be able to
        update this file at runtime (e.g. `lastChangelogVersion`)
        because it is a read-only nix store symlink.
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf (lib.types.coercedTo
        (lib.types.either lib.types.package lib.types.path)
        (p: { package = p; extraPackages = [ ]; })
        (lib.types.submodule {
          options = {
            package = lib.mkOption {
              type = lib.types.either lib.types.package lib.types.path;
              description = ''
                Plugin package: a derivation (or path) whose `$out` is
                a pi-package-shaped directory.
              '';
            };
            extraPackages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = ''
                Native runtime dependencies that should be on pi's
                PATH when it runs this plugin (e.g. a CLI that the
                extension shells out to). Aggregated into a wrapper
                around `programs.pi.package` (via `symlinkJoin` +
                `makeWrapper`), so these binaries are visible to pi
                and any subprocess it spawns, but NOT on the user's
                global PATH. Mirrors home-manager's `nvim` plugin
                extraPackages convention.
              '';
            };
          };
        })
      );
      default = [ ];
      example = lib.literalExpression ''
        let
          piPlugins = import ./agents/pi/plugins.nix { inherit pkgs lib; };
        in [
          # Simple: bare derivation, coerced to { package = it; extraPackages = []; }
          (piPlugins.mkPiPluginFromFile {
            name = "modal-editor";
            file = "''${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/examples/extensions/modal-editor.ts";
          })

          # Complex: explicit attrset with native runtime deps
          {
            package       = piPlugins.mkPiPlugin { name = "foo"; src = fooPkg; };
            extraPackages = [ fooPkg ];  # exposes bin/foo on PATH
          }
        ]
      '';
      description = ''
        Third-party pi plugins to install. Each entry is either:

          * a derivation / path (coerced to `{ package = it; extraPackages = []; }`), or
          * an attrset `{ package; extraPackages ? []; }`.

        `package` is a directory in the pi-package convention layout
        (extensions/, skills/, prompts/, themes/) or any directory
        whose `package.json` carries a `pi` manifest. Its store path
        is appended to `settings.packages`.

        `extraPackages` are nixpkgs derivations whose `bin/` should be
        on PATH when pi runs (for plugins that shell out to a CLI).

        See `agents/pi/plugins.nix` for `mkPiPluginFromFile` /
        `mkPiPlugin` helpers, and `agents/pi/npm-plugins/` for worked
        examples covering npm-deps and CLI-shipping plugins.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Wrap pi so plugin `extraPackages` are on its PATH but not the
    # user's global PATH. Mirrors the home-manager neovim wrapper:
    # extra runtime deps are visible to the wrapped tool (and to any
    # subprocess it spawns, including pi's plugin hooks) and nowhere
    # else. When no plugin contributes extraPackages, fall through to
    # the unwrapped package to avoid an unnecessary derivation.
    home.packages =
      let
        pluginBins = lib.concatMap (p: p.extraPackages) cfg.plugins;
        wrappedPi  = pkgs.symlinkJoin {
          name = "${cfg.package.name}-with-plugin-deps";
          paths = [ cfg.package ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            for bin in $out/bin/*; do
              wrapProgram "$bin" \
                --prefix PATH : "${lib.makeBinPath pluginBins}"
            done
          '';
        };
      in
      [ (if pluginBins == [ ] then cfg.package else wrappedPi) ];

    home.file = lib.mkMerge [
      {
        ".pi/agent/settings.json".source =
          let
            pluginPaths = map (p: toString p.package) cfg.plugins;
            mergedSettings = cfg.settings // {
              packages = (cfg.settings.packages or [ ]) ++ pluginPaths;
            };
          in
          settingsFormat.generate "pi-settings.json" mergedSettings;
      }
      (
        if lib.isPath cfg.context then {
          ".pi/agent/AGENTS.md".source = cfg.context;
        } else
          lib.mkIf (cfg.context != "") {
            ".pi/agent/AGENTS.md".text = cfg.context;
          }
      )
    ];
  };
}

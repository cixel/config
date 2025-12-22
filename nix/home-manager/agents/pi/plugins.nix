{ pkgs, lib }:

# Helpers for packaging pi (https://github.com/badlogic/pi-coding-agent)
# extensions/skills/prompts/themes as nix derivations.
#
# Pi's "package" concept (see docs/packages.md upstream) accepts a
# directory on disk and auto-discovers resources from convention
# subdirectories when no `pi` manifest is present in package.json:
#
#   extensions/   *.ts, *.js
#   skills/       SKILL.md folders + top-level *.md
#   prompts/      *.md
#   themes/       *.json
#
# Each helper here produces a derivation whose `$out` is one such
# directory. Feed the resulting derivations into `programs.pi.plugins`
# (see ../../pi.nix) and they'll be appended to `settings.packages`.
#
# `src` can be anything that resolves to a directory: a local repo
# path, `pkgs.fetchFromGitHub`, a path inside another package like
# `pkgs.pi-coding-agent`, etc. Whatever produces the source is also
# what pins the plugin's version.
#
# Plugins with runtime npm dependencies are out of scope for these
# helpers. If/when one shows up, wrap it in `pkgs.buildNpmPackage`
# instead and feed the resulting derivation in as a plugin.

let
  inherit (lib) escapeShellArg;
  inherit (builtins) baseNameOf toString;

  validKinds = [ "extensions" "skills" "prompts" "themes" ];
in
rec {
  # Wrap a single file as a pi plugin package.
  #
  # Example:
  #   mkPiPluginFromFile {
  #     name = "modal-editor";
  #     file = "${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/examples/extensions/modal-editor.ts";
  #   }
  #
  # `kind` selects the convention dir the file lands in; defaults to
  # "extensions" which is the common case.
  mkPiPluginFromFile =
    { name
    , file
    , kind ? "extensions"
    , filename ? null
    }:
    assert lib.assertOneOf "kind" kind validKinds;
    let
      finalName = if filename != null then filename else baseNameOf (toString file);
    in
    pkgs.runCommandLocal "pi-plugin-${name}" { passthru = { piPlugin = true; }; } ''
      mkdir -p $out/${kind}
      cp ${file} $out/${kind}/${escapeShellArg finalName}
    '';

  # Wrap an existing source tree as a pi plugin package.
  #
  # The simplest invocation just copies `src` into `$out`. If the
  # upstream layout doesn't match pi's conventions (e.g. the
  # extensions live in `examples/extensions/` rather than top-level
  # `extensions/`), pass `pickPaths` to remap them:
  #
  #   mkPiPlugin {
  #     name = "my-pi-pack";
  #     src  = pkgs.fetchFromGitHub {
  #       owner = "someone"; repo = "my-pi-pack"; rev = "v1.0.0";
  #       hash = "sha256-...";
  #     };
  #     pickPaths = {
  #       extensions = "examples/extensions";
  #       skills     = "examples/skills";
  #     };
  #   }
  #
  # `pickPaths` values are paths relative to `src`. Each becomes the
  # corresponding convention dir at `$out/<kind>/`. If `pickPaths` is
  # null (the default), `src` is copied wholesale and pi will use its
  # `package.json` manifest or convention dirs as they exist upstream.
  mkPiPlugin =
    { name
    , src
    , pickPaths ? null
    , postBuild ? ""
    }:
    pkgs.runCommandLocal "pi-plugin-${name}" {
      inherit src;
      passthru = { piPlugin = true; };
    } (
      if pickPaths == null && postBuild == "" then
        # Fast path: no remapping or post-processing needed. Just
        # symlink $out to $src so pi reads the upstream tree
        # directly. Avoids copying potentially-large node_modules
        # trees from `buildNpmPackage` outputs. Relative paths in
        # `package.json#pi` still resolve correctly through the
        # symlink.
        ''
          ln -s $src $out
        ''
      else if pickPaths == null then ''
        mkdir -p $out
        cp -RL $src/. $out/
        chmod -R u+w $out
        ${postBuild}
      '' else
        let
          copyOne = kind: relPath: ''
            mkdir -p $out/${kind}
            cp -RL $src/${relPath}/. $out/${kind}/
          '';
          copyCmds = lib.concatStringsSep "\n" (
            lib.mapAttrsToList copyOne pickPaths
          );
        in ''
          mkdir -p $out
          ${copyCmds}
          chmod -R u+w $out
          ${postBuild}
        ''
    );
}

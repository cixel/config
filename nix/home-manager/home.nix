{ darwin }:
{ config, pkgs, lib, ... }:
{
  imports = [ ./pi.nix ];

  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  # programs.go.env only writes Go's internal env file (~/.config/go/env).
  # Export the same values to the shell so $GOPATH/$GOBIN are usable directly
  # (e.g. in fish.nix's PATH setup) without forking `go env`.
  home.sessionVariables = {
    GOPATH = "${config.home.homeDirectory}/gopath";
    GOBIN = "${config.home.homeDirectory}/gobin";
  };

  home.packages = with pkgs; let
    hunk = pkgs.callPackage ./hunk.nix { };
  in [
    git
    curl
    bat
    eza
    # glances # top alternative
    hyperfine # benchmarking
    fd
    graphviz
    jq
    tokei
    age
    luajit
    rustup
    zig

    # this won't be useable as a server because it's only available to a single
    # user.
    mosh
    openssh

    # i use these for work and prefer having them already loaded to avoid
    # needing to enter a nix shell for random build dependencies
    golangci-lint
    xz
    gnumake

    podman
    podman-compose

    ffmpeg

    # watchman # for jj
    hunk
  ];

  home.shellAliases = {
    hms =
      if darwin then
        "sudo -E nix run nix-darwin -- -v -L switch --flake $HOME/.config"
      else
        "sudo nixos-rebuild switch -v --flake $HOME/.config";

    v = "nvim";
    sudov = "sudo -E -s nvim";

    l = "eza --long --all";
    lg = "eza --long --all --git-ignore";
    lt = "eza --long --all --sort newest";
    ls = "eza";
    tree = "eza --tree --long";

    gd = "go doc";
    gdu = "go doc -u";

    docker = "podman";

    gitlines = "git ls-files | xargs wc -l";
  };

  programs.pi =
    let
      piPlugins      = import ./agents/pi/plugins.nix              { inherit pkgs lib; };
      contextModePlg = import ./agents/pi/npm-plugins/context-mode.nix { inherit pkgs lib; };
      # piSkillsPlg    = import ./agents/pi/npm-plugins/pi-skills.nix    { inherit pkgs lib; };

      # Override the upstream pi-coding-agent (currently pinned to
      # 0.75.4 in nixpkgs unstable) with a newer release. The build
      # recipe in nixpkgs has been stable across recent versions, so
      # we only need to swap `version`, `src`, and the npm deps hash.
      #
      # Refreshing the version:
      #   1. Bump `piVersion`.
      #   2. Set `piSrcHash` to lib.fakeHash, run `hms`, copy the
      #      "got:" hash from the failure into `piSrcHash`.
      #   3. Set `piNpmDepsHash` to lib.fakeHash, run `hms` again,
      #      copy the "got:" hash from prefetch-npm-deps in.
      # Or, offline:
      #   nix-prefetch-url --unpack --type sha256 \
      #     https://github.com/earendil-works/pi/archive/refs/tags/vX.Y.Z.tar.gz
      #   (then `nix hash convert --to sri ...`)
      #   nix run nixpkgs#prefetch-npm-deps -- <unpacked>/package-lock.json
      piVersion     = "0.79.1";
      piSrcHash     = "sha256-MvH8e21GVfzRQ9vsxFNC1GHJfB9GZpqY1Z2t8GCUaiQ=";
      piNpmDepsHash = "sha256-ZWdfDDs+Hv+GWTmsNmpWNlUDBOMALw7H4lwo7CJHVCM=";

      piPackage = pkgs.pi-coding-agent.overrideAttrs (finalAttrs: prevAttrs: {
        version = piVersion;
        src = pkgs.fetchFromGitHub {
          owner = "earendil-works";
          repo  = "pi";
          tag   = "v${finalAttrs.version}";
          hash  = piSrcHash;
        };
        npmDeps = prevAttrs.npmDeps.overrideAttrs {
          inherit (finalAttrs) src;
          outputHash = piNpmDepsHash;
        };

        # v0.78.0 drops the koffi native FFI dep, but the nixpkgs
        # 0.75.4 derivation's darwin postInstall hard-references
        # node_modules/koffi/build/koffi and aborts when the dir is
        # gone. Make that one `find` tolerant of a missing path
        # instead of duplicating the whole postInstall, so future
        # nixpkgs bumps still flow through unchanged.
        postInstall = lib.replaceStrings
          [ ''find "$nm/koffi/build/koffi"'' ]
          [ ''[ -d "$nm/koffi/build/koffi" ] && find "$nm/koffi/build/koffi"'' ]
          prevAttrs.postInstall;
      });
    in
    {
      enable = true;
      package = piPackage;
      context = ./agents/context.md;
      settings = {
        defaultProvider = "anthropic";
        defaultModel = "claude-opus-4-8";
        defaultThinkingLevel = "high";
        enableSkillCommands = true;
        theme = "dark";
        skills     = [ "~/.config/nix/home-manager/agents/skills" ];
        prompts    = [ "~/.config/nix/home-manager/agents/commands" ];
        # extensions = [ "~/.config/nix/home-manager/agents/pi/extensions" ];
      };

      # Third-party plugins, pinned via nix. `src`/`file` can be
      # anything: pkgs.fetchFromGitHub, a path inside another nix
      # package, or a path inside this repo. See agents/pi/plugins.nix.
      plugins = [
        # pi-vim: vim-style modal editing for the prompt editor.
        # Upstream package.json declares a `pi.extensions` manifest
        # pointing at ./index.ts, so the source tree is consumed
        # as-is with no path remapping.
        (piPlugins.mkPiPlugin {
          name = "pi-vim";
          src = pkgs.fetchFromGitHub {
            owner = "lajarre";
            repo  = "pi-vim";
            rev   = "v0.3.2";
            hash  = "sha256-DGOWfuLhozXLsWPF3jdGdlmMKGyWZYfzF2V0SsXcDV0=";
          };
        })

        # context-mode: MCP-style context saver. See the npm-plugins file
        # for design notes; it bundles extension + skills + a CLI bin.
        # contextModePlg

        # pi-skills: bundles the `brave-search` and `browser-tools`
        # skills from https://github.com/badlogic/pi-skills, with
        # their npm deps vendored via buildNpmPackage so node can
        # invoke the helper scripts without a runtime `npm install`.
        # piSkillsPlg
      ];
    };

  programs.neovim = import ./nvim { inherit pkgs; };
  programs.starship = import ./starship.nix { inherit pkgs lib; };
  programs.tmux = import ./tmux.nix { inherit pkgs config; };
  programs.zsh = import ./zsh.nix { inherit pkgs; };
  programs.fish = import ./fish.nix { inherit darwin pkgs; };
  programs.ghostty = import ./ghostty.nix { inherit pkgs; };
  programs.git = import ./git.nix { inherit lib; };
  programs.jujutsu = import ./jujutsu.nix { inherit lib; };

  programs.atuin = {
    enable = true;
    daemon.enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      update_check = false;
      auto_sync = false;
      style = "compact";
      inline_height = 20;
      filter_mode_shell_up_key_binding = "session";
      search_mode = "daemon-fuzzy";
      keymap_mode = "vim-insert";
    };
  };

  # The home-manager atuin module defaults the daemon launchd agent to the
  # `user` domain (modules/programs/atuin.nix). On this machine, bootstrapping
  # into `user/<uid>` fails with EIO (`Bootstrap failed: 5: Input/output
  # error`), while the `gui` domain loads fine and matches the at-login
  # auto-load behaviour of ~/Library/LaunchAgents. Plain assignment overrides
  # the module's lib.mkDefault.
  launchd.agents.atuin-daemon.domain = lib.mkForce "gui";

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
    enableFishIntegration = true;

    defaultCommand = "${pkgs.fd}/bin/fd";
    fileWidgetCommand = "${pkgs.fd}/bin/fd --hidden --exclude '.git'";
    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d --hidden --exclude '.git' --follow";
  };

  programs.ripgrep = {
    enable = true;
    arguments = [
      "--glob"
      "!.git/*"
      "--glob"
      "!.jj/*"
      "--glob"
      "!node_modules/*"
      "--hidden"
    ];
  };

  programs.go = {
    enable = true;
    # nixpkgs only packages up to go_1_26; build the go1.27 release candidate
    # from upstream source by overriding the 1.26 derivation. Revisit once
    # nixpkgs ships go_1_27 (then this can drop back to pkgs.go).
    package = pkgs.go_1_26.overrideAttrs (old: rec {
      version = "1.26.4";
      src = pkgs.fetchurl {
        url = "https://go.dev/dl/go${version}.src.tar.gz";
        hash = "sha256-T2aKMvv8ETLmqIH7lowvHa2mMUkqM5IRc1+7JVpCYC0=";
      };
      # The go1.26 vendor-checks patch adds an opt-in GO_NO_VENDOR_CHECKS
      # escape hatch, but its import.go hunk no longer applies to 1.27rc1
      # (the helper receiver was renamed loaderstate -> ld). Drop the patch
      # and re-apply the equivalent additive edits inline.
      # patches = builtins.filter
      #   (p: !lib.hasSuffix "go_no_vendor_checks-1.26.patch" (toString p))
      #   old.patches;
      # postPatch = (old.postPatch or "") + ''
      #   substituteInPlace src/cmd/go/internal/modload/import.go \
      #     --replace-fail \
      #     'gover.ExplicitModulesTxtImportVersion) < 0) {' \
      #     'gover.ExplicitModulesTxtImportVersion) < 0) || os.Getenv("GO_NO_VENDOR_CHECKS") == "1" {'
      #   substituteInPlace src/cmd/go/internal/modload/vendor.go \
      #     --replace-fail \
      #     'if gover.Compare(index.goVersion, "1.14") < 0 {' \
      #     'if gover.Compare(index.goVersion, "1.14") < 0 || (os.Getenv("GO_NO_VENDOR_CHECKS") == "1" && len(vendorMeta) == 0) {'
      # '';
    });
    telemetry = {
      mode = "on";
    };
    # these are interpreted relative to $HOME
    env = {
      GOBIN = "${config.home.homeDirectory}/gobin";
      GOPATH = "${config.home.homeDirectory}/gopath";
      GOPRIVATE = [
        # TODO: it'd be nice if this is only set on work machines but that'd take a
        # refactor
        "github.com/Contrast-Security-Inc/*"
      ];
    };
  };

  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-stack ];
    settings = {
      git_protocol = lib.mkDefault "ssh";
      aliases = {
        merge = ''!
          desc=$(gh pr view "$1" --json commits --jq '.commits[0].messageHeadline');
          gh pr merge "$1" --rebase --delete-branch --subject "$desc"
        '';
        sync = ''!
          title=$(gh pr view "$1" --json commits --jq '.commits[0].messageHeadline');
          body=$(gh pr view "$1" --json commits --jq '.commits[0].messageBody');
          gh pr edit "$1" --title "$title" --body "$body"
        '';
      };
    };
  };
}

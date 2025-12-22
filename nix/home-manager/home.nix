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
    ghmerge = writeShellScriptBin "ghmerge" ''
      desc=$(gh pr view "$1" --json commits --jq '.commits[0].messageHeadline')
      gh pr merge "$1" --rebase --delete-branch --subject "$desc"
    '';
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

    watchman # for jj
    ghmerge
  ];

  home.shellAliases = {
    hms =
      if darwin then
        "sudo -E nix run nix-darwin -- -v -L switch --flake path:$HOME/.config"
      else
        "sudo nixos-rebuild switch -v --flake path:$HOME/.config";

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
      gondolinPlg    = import ./agents/pi/npm-plugins/gondolin.nix     {
        inherit pkgs lib;
        # Baked into the sandbox VM image. `gp` is this config's nixpkgs
        # (same overlays/config) for the guest's Linux platform, so these
        # are the same jj overlay and go.nix pin as on the host.
        guestTools = gp: [ gp.nix gp.jujutsu (import ./go.nix { pkgs = gp; }) ];
      };
      # piSkillsPlg    = import ./agents/pi/npm-plugins/pi-skills.nix    { inherit pkgs lib; };
    in
    {
      enable = true;
      context = ./agents/context.md;
      settings = {
        defaultProvider = "anthropic";
        defaultModel = "claude-opus-5-5";
        defaultThinkingLevel = "high";
        enableSkillCommands = true;
        theme = "dark";
        # Fullscreen (pi 1.0 default) uses the alt screen and captures the
        # mouse, which breaks tmux scrollback/copy-mode. I pretty much always
        # run Pi in tmux here, so use the terminal's native scrollback instead.
        tuiMode = "regular";
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

        # jj-footer: show the jj change id (and workspace name in
        # multi-workspace repos) in the footer slot where pi would
        # otherwise print "(detached)" for a colocated jj repo.
        (piPlugins.mkPiPluginFromFile {
          name = "jj-footer";
          file = ./agents/pi/extensions/jj-footer.ts;
        })

        # footer-status: move extension statuses (fence, guard, ...)
        # from their own footer line into the empty right-hand side of
        # the cwd line, falling back to the stock layout when narrow.
        (piPlugins.mkPiPluginFromFile {
          name = "footer-status";
          file = ./agents/pi/extensions/footer-status.ts;
        })

        # gondolin: run read/write/edit/bash and user ! commands in a
        # micro-VM, with the current project mounted at /workspace.
        # DISABLED on purpose: pi-fence (appended by the module; see
        # agents/pi/pi-fence.md) is the default host-native protection,
        # and the two cannot be co-installed — both override the bash
        # tool and last registration silently wins. gondolin stays built
        # and tested (flake pi-gondolin* outputs) for the untrusted-code
        # case; a per-session pi-vm mode switch is a documented followup.
        # gondolinPlg

        # context-mode: MCP-style context saver. See the npm-plugins file
        # for design notes; it bundles extension + skills + a CLI bin.
        # contextModePlg

        # pi-skills: bundles the `brave-search` and `browser-tools`
        # skills from https://github.com/badlogic/pi-skills, with
        # their npm deps vendored via buildNpmPackage so node can
        # invoke the helper scripts without a runtime `npm install`.
        # piSkillsPlg
      ];

      # jev-guard: second barrier between the agent and destructive or
      # unauthorized actions (rm outside the project, git push, ...).
      # Appended last by the module. Plan: agents/pi/jev-guard-plan.md.
      # Needs `/login typesafe` once per machine for the jev half;
      # work machines turn jev off in work.nix.
      jevGuard.enable = true;
    };

  programs.neovim = import ./nvim { inherit pkgs; };
  programs.starship = import ./starship.nix { inherit pkgs lib; };
  programs.tmux = import ./tmux.nix { inherit pkgs; };
  programs.zsh = import ./zsh.nix { inherit pkgs; };
  programs.fish = import ./fish.nix { inherit darwin pkgs; };
  programs.ghostty = import ./ghostty.nix { inherit pkgs; };
  programs.git = import ./git.nix { inherit lib; };
  programs.jujutsu = import ./jujutsu.nix { inherit lib; };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      update_check = false;
      auto_sync = false;
      style = "compact";
      inline_height = 20;
      filter_mode_shell_up_key_binding = "session";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
    enableFishIntegration = true;

    defaultCommand = "fd";
    fileWidgetCommand = "fd --hidden --exclude '.git'";
    changeDirWidgetCommand = "fd --type d --hidden --exclude '.git' --follow";
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
    package = pkgs.go;
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

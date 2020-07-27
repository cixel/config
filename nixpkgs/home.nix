{ config, pkgs, ... }:

let
  # set channel channel to nixpkgs-unstable
  nixpkgs = import <nixpkgs> {};

  # https://discourse.nixos.org/t/is-it-possible-to-override-cargosha256-in-buildrustpackage/4393/2
  starship = nixpkgs.starship.overrideAttrs (drv: rec {
    src = nixpkgs.fetchFromGitHub {
      owner = "starship";
      repo = "starship";
      rev = "a89f41f8e8e3691d6499357509ff5f293dcf8007";
      sha256 = "0fqbbax783bp066wqhb3qmiw262da25kjb2ypsfcq3k8bxxw8qlr";
    };
    cargoDeps = drv.cargoDeps.overrideAttrs (nixpkgs.lib.const {
      inherit src;
      outputHash = "0j0l5gngkdyns83r5aplr9psvhd9mff7s9r4h2dfial07jm5rwds";
    });
  });

  # starship_src = import ./starship.nix;
  # starship = nixpkgs.callPackage starship_src { Security= nixpkgs.darwin.apple_sdk.frameworks.Security; };
  # mozilla-overlays = fetchTarball {
  #     url = https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz;
  # };
in
{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "20.03";

  # Allow installation of propietary of "unfree" packages. Needed for parts of
  # mozilla overlay.
  # nixpkgs.config.allowUnfree = true;
  # nixpkgs.overlays = [ (import "${mozilla-overlays}") ];


  home.packages = [
    nixpkgs.git
    nixpkgs.bat
    nixpkgs.exa
    nixpkgs.fd
    nixpkgs.graphviz
    nixpkgs.jq
    starship
    # nixpkgs.starship
    nixpkgs.tokei
    nixpkgs.fd
    nixpkgs.modd
    nixpkgs.automake
    nixpkgs.autoconf
    nixpkgs.hugo
    nixpkgs.ffmpeg-full
    nixpkgs.age
    nixpkgs.silver-searcher
    nixpkgs.zlib
    nixpkgs.llvm_10
    nixpkgs.lldb_10
    nixpkgs.libwebp

    # nixpkgs.coreutils-full

    nixpkgs.python
    nixpkgs.python3

    nixpkgs.lua5_3

    # rust. eventually, see about using
    # https://github.com/mozilla/nixpkgs-mozilla
    # rustup manages rustc, cargo, etc. perhaps it
    # should also manage rust-analyzer?
    nixpkgs.rustup
    nixpkgs.rust-analyzer
    # pkgs.cargo
    # pkgs.rustfmt

    # nix language server
    nixpkgs.rnix-lsp

    # I can add the tmux.conf here as well
    nixpkgs.tmux
  ];

  programs.zsh = {
    enable = true;
    defaultKeymap = "viins";
    shellAliases = {
      v = "nvim";
      vim = "nvim";

      l = "exa -la";
      ls = "exa";
      tree = "exa --tree --long";

      gd = "go doc";
      gdu = "go doc -u";

      hm = "home-manager";
      tmux = "tmux -2";
      gitlines = "git ls-files | xargs wc -l";
      ack = "ag --ignore-dir=node_modules --ignore-dir=labs --ignore-dir=docs --ignore-dir=dist --ignore-dir=code-coverage-report";
    };
    profileExtra = ''
      if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then . $HOME/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
    '';
    sessionVariables = {
      KEYTIMEOUT = 1;
      EDITOR = "nvim";
    };
    initExtraBeforeCompInit = ''
    '';
    initExtra = ''
      if [ -f $HOME/.sensitive ]; then . $HOME/.sensitive; fi

      ### Paste utils and auto escaping URLs
      autoload -Uz bracketed-paste-magic
      zle -N bracketed-paste bracketed-paste-magic
      autoload -Uz url-quote-magic
      zle -N self-insert url-quote-magic

      ### Completion menu with colors
      zstyle ':completion:*' menu select
      zstyle ':completion:*default' list-colors ''${(s.:.)LSCOLORS}

      ### Press 'V' in vi mode to open current command in vim
      autoload -U edit-command-line
      zle -N edit-command-line
      bindkey -M vicmd V edit-command-line

      eval "$(starship init zsh)"
    '';
    envExtra = ''
      # may want to fiddle with these so ~/go is just my one source for all
      # things outside of the toolchain and ~/golang is for inside
      export GOBIN="$HOME/gobin"
      export GOPATH="$HOME/gopath"
      export PATH="$GOBIN:$PATH"
      export PATH="$GOPATH/bin:$PATH"
      export PATH="$HOME/.cargo/bin:$PATH"
    '';
    plugins = [
      {
        name = "fzf-tab";
        file = "fzf-tab.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "Aloxaf";
          repo = "fzf-tab";
          rev = "d1dbe14870be2b4d19aa7ea49a05ce9906e461a5";
          sha256 = "1j6nrmhcdsabf98dqi87s5cf9yb5017xwnd7fxn819i18h2lf46i";
        };
      }
    ];
  };

  programs.tmux = {
    enable = true;
    package = nixpkgs.tmux;
    shortcut = "a";
    keyMode = "vi";
    escapeTime = 0;
    clock24 = true;
    # baseIndex = 1;
    sensibleOnTop = true;
    terminal = "screen-256color";
    plugins =  with nixpkgs; [
      {
        plugin = tmuxPlugins.cpu;
        extraConfig = ''
          ### I can put these all in the color scheme section at the bottom,
          ### maybe? then use #{cpu_bg_color} instead of the color strings I'm
          ### using
          # set -g @cpu_low_fg_color "#[fg=colour246]"
          # set -g @cpu_medium_fg_color "#[fg=colour246]"
          # set -g @cpu_high_fg_color "#[fg=colour246]"
          # set -g @cpu_low_bg_color "#[bg=colour237]"
          # set -g @cpu_medium_bg_color "#[bg=colour237]"
          # set -g @cpu_high_bg_color "#[bg=colour237]"
          set -g @cpu_percentage_format " cpu: %3.1f%% "

          # set -g @ram_low_fg_color "#[fg=colour246]"
          # set -g @ram_medium_fg_color "#[fg=colour246]"
          # set -g @ram_high_fg_color "#[fg=colour246]"
          # set -g @ram_low_bg_color "#[bg=colour239]"
          # set -g @ram_medium_bg_color "#[bg=colour239]"
          # set -g @ram_high_bg_color "#[bg=colour239]"
          set -g @ram_percentage_format " mem: %3.1f%% "

          set-option  -g status-right '#[fg=colour246, bg=colour237]#{cpu_percentage}'
          set-option -ag status-right '#[fg=colour246, bg=colour238]#{ram_percentage}'
        '';
      }
      {
        plugin = tmuxPlugins.battery;
        extraConfig = ''
          set-option  -ag status-right '#[fg=colour246, bg=colour239, nobold, nounderscore, noitalics] batt: #{battery_percentage} '
        '';
      }
      tmuxPlugins.vim-tmux-navigator
      tmuxPlugins.resurrect
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
    ];
    extraConfig = ''
      set -g terminal-overrides ",alacritty:RGB"

      set -g base-index 1
      set -g pane-base-index 1

      #### so that i can programatically change title from vim
      set-option -g set-titles on

      ##### copy to keyboard with vim binding
      bind-key v split-window -h

      ##### copy to keyboard with vim binding
      unbind-key -T copy-mode-vi Space     ;   bind-key -T copy-mode-vi v send-keys -X begin-selection
      unbind-key -T copy-mode-vi Enter     ;   bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
      unbind-key -T copy-mode-vi C-v       ;   bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      unbind-key -T copy-mode-vi [         ;   bind-key -T copy-mode-vi [ send-keys -X begin-selection
      unbind-key -T copy-mode-vi ]         ;   bind-key -T copy-mode-vi ] send-keys -X copy-selection

      #### prefix + prefix window swapping
      bind-key a last-window
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      #### mouse mode
      set -g mouse on

      #### send prefix (so C-b works as prefix on remote)
      bind-key -n C-b send-prefix

      ## COLORSCHEME: gruvbox dark
      set-option -g status "on"

      # default statusbar color
      set-option -g status-style bg=colour237,fg=colour223 # bg=bg1, fg=fg1

      # default window title colors
      set-window-option -g window-status-style bg=colour214,fg=colour237 # bg=yellow, fg=bg1

      # default window with an activity alert
      set-window-option -g window-status-activity-style bg=colour237,fg=colour248 # bg=bg1, fg=fg3

      # active window title colors
      set-window-option -g window-status-current-style bg=red,fg=colour237 # fg=bg1

      # pane border
      set-option -g pane-active-border-style fg=colour250 #fg2
      set-option -g pane-border-style fg=colour237 #bg1

      # message infos
      set-option -g message-style bg=colour239,fg=colour223 # bg=bg2, fg=fg1

      # writing commands inactive
      set-option -g message-command-style bg=colour239,fg=colour223 # bg=fg3, fg=bg1

      # pane number display
      set-option -g display-panes-active-colour colour250 #fg2
      set-option -g display-panes-colour colour237 #bg1

      # clock
      set-window-option -g clock-mode-colour colour109 #blue

      # bell
      set-window-option -g window-status-bell-style bg=colour167,fg=colour235 # bg=red, fg=bg

      ## Theme settings mixed with colors (unfortunately, but there is no cleaner way)
      ## NOTE(ehden): there actually may be a cleaner way to set backgrounds on
      # individual plugins via their own options. see
      # https://github.com/tmux-plugins/tmux-cpu#customization
      set-option -g status-justify "left"
      set-option -g status-left-style none
      set-option -g status-left-length "80"
      set-option -g status-right-style none
      set-option -g status-right-length "80"
      set-window-option -g window-status-separator ""

      set-option -g status-left "#[fg=colour247, bg=colour241] #S "
      set-option -ag status-right "#[fg=colour237, bg=colour248]%l:%M %p %a %d-%b-%y "
      # END COLORSCHEME
    '';
  };

  programs.neovim = {
    enable = true;

    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;

    extraConfig = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/init.vim";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
    enableFishIntegration = false;

    defaultCommand = "fd";
    fileWidgetCommand = "fd --hidden --exclude '.git'";
    changeDirWidgetCommand = "fd --type d --hidden --exclude '.git' --follow";
  };

  # programs.go = {
  #   enable = true;
  #   goPath = "${builtins.getEnv "HOME"}/gopath";
  #   goBin = "${builtins.getEnv "HOME"}/gobin";
  # };

  #programs.git = {
  #	package = pkgs.gitAndTools.gitFull;
  #  userName = Ehden Sinai;
  #  userEmail = ehdens@gmail.com;

  #  extraConfig = {
  #  	core = {
  #  		autocrlf = input;
  #  		quotepath = false;
  #  		commitGraph = true;
  #  	};
  #  	rerere = { enabled = true; };
  #  };

  #  aliases = {
  #  	lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'
  #  	aa = add -A .
  #  	fpush = push --force-with-lease
  #  	st = status
  #  	ci = commit
  #  	co = checkout
  #  	cp = cherry-pick
  #  	put = push origin HEAD
  #  	fixup = !sh -c 'git commit --no-verify -m \"fixup! $(git log -1 --format='\\''%s'\\'' $@)\"' -
  #  	squash = !sh -c 'git commit --no-verify -m \"squash! $(git log -1 --format='\\''%s'\\'' $@)\"' -
  #  	doff = reset head^
  #  	ri = rebase --interactive
  #  	br = branch
  #  	pruneremote = remote prune origin
  #  	tree = log --graph --oneline --decorate --color --all
  #  	tr = log --graph --oneline --decorate --color
  #  	unpushed = !"PROJ_BRANCH=$(git symbolic-ref HEAD | sed 's|refs/heads/||') && git log origin/$PROJ_BRANCH..HEAD"
  #  	unpulled = !"PROJ_BRANCH=$(git symbolic-ref HEAD | sed 's|refs/heads/||') && git fetch && git log HEAD..origin/$PROJ_BRANCH"
  #  	add-untracked = !"git status --porcelain | awk '/\\?\\?/{ print $2 }' | xargs git add"
  #  	ln = log --pretty=format:'%Cblue%h %Cred* %C(yellow)%s'
  #  	reset-authors = commit --amend --reset-author -CHEAD
  #  	rmbranch = "!f(){ git branch -d ${1} && git push origin --delete ${1}; };f"
  #  	snapshot = !git stash save "snapshot: $(date)" && git stash apply "stash@{0}" --abbrev-commit --date=relative
  #  	stash = git stash push
  #  	save = commit -m "saving" --no-verify
  #  	rpull = pull -r
  #  };
  #};
}

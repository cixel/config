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
        # https://github.com/Aloxaf/fzf-tab
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

  programs.tmux = import ./tmux-conf.nix { pkgs = nixpkgs; };

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

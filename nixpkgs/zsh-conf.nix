{ pkgs }:
{
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
    #XDG_RUNTIME_DIR="/run/user/$(id -u)"; # https://github.com/Trundle/NixOS-WSL/issues/18
  };
  initExtraBeforeCompInit = ''
    '';
  initExtra = ''
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

    # shortcuts for spitting out an svg from .dot; TODO see about moving this
    # into a derivation around graphviz
    function svg {
          dot -Tsvg $1 -o $1.svg
    }

    #sudo loginctl enable-linger "$USER" # https://github.com/Trundle/NixOS-WSL/issues/18
    #eval "$(direnv hook zsh)"
    eval "$(starship init zsh)"
  '';
  envExtra = ''
    if [ -f $HOME/go/bin/go ]; then alias godev="$HOME/go/bin/go"; fi
    if [ -f $HOME/.sensitive ]; then . $HOME/.sensitive; fi

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
}

{ pkgs }:
{
  enable = true;
  defaultKeymap = "viins";
  shellAliases = {
    v = "nvim";
    vim = "nvim";
    sudov = "sudo -E -s nvim";

    l = "eza --long --all";
    lt = "eza --long --all --sort newest";
    ls = "eza";
    tree = "eza --tree --long";
    exa = "eza";

    gd = "go doc";
    gdu = "go doc -u";

    hm = "home-manager";
    tmux = "tmux -2";
    gitlines = "git ls-files | xargs wc -l";
    ack = "ag --ignore-dir=node_modules --ignore-dir=labs --ignore-dir=docs --ignore-dir=dist --ignore-dir=code-coverage-report";
  };
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
  '';
  envExtra = ''
    if [ -f $HOME/go/bin/go ]; then alias godev="$HOME/go/bin/go"; fi
    if [ -f $HOME/.sensitive ]; then . $HOME/.sensitive; fi

    if [ -f /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
      alias tailscale=/Applications/Tailscale.app/Contents/MacOS/Tailscale
    fi

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
        rev = "5a81e13792a1eed4a03d2083771ee6e5b616b9ab";
        sha256 = "sha256-dPe5CLCAuuuLGRdRCt/nNruxMrP9f/oddRxERkgm1FE=";
      };
    }
  ];
}

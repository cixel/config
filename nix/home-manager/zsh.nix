{ pkgs }:
{
  enable = true;
  defaultKeymap = "viins";
  sessionVariables = {
    KEYTIMEOUT = 1;
    #XDG_RUNTIME_DIR="/run/user/$(id -u)"; # https://github.com/Trundle/NixOS-WSL/issues/18
  };
  initExtraBeforeCompInit = "";
  initContent = ''
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
    # if [ -f $HOME/.sensitive ]; then . $HOME/.sensitive; fi

    # Avoid forking `go env` from .zshenv: on work machines with EndpointSecurity
    # interception (Falcon/Netskope/Jamf), a SIGCHLD-delivery race in zsh's
    # waitforpid can hang interactive shells until a SIGWINCH unsticks them.
    export GOPATH="$HOME/go"
    export GOBIN="$HOME/gobin"
    export PATH="$GOBIN:$GOPATH/bin:$HOME/.cargo/bin:$PATH"
  '';
  plugins = [
    {
      # https://github.com/Aloxaf/fzf-tab
      name = "fzf-tab";
      file = "fzf-tab.zsh";
      src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
    }
  ];
}

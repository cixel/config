# uncomment to enable startup time logging
# zmodload zsh/zprof

# Path to your oh-my-zsh installation.
# export ZSH=~/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
# ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

source ~/.config/lazynvm.sh
# export NVM_DIR=~/.nvm
# export NVM_LAZY_LOAD=true
# source $(brew --prefix nvm)/nvm.sh --no-use

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git vi-mode node wd)
# plugins=(git vi-mode wd zsh-nvm)
# plugins=(vi-mode wd fzf)
plugins=(vi-mode wd)
export KEYTIMEOUT=1

### Completion
fpath=($HOME/.zsh/completions $fpath)
autoload -U compinit && compinit -u
zstyle ':completion:*' menu select

# Colorize completions using default `ls` colors.
export LS_COLORS=$LSCOLORS
zstyle ':completion:*default' list-colors ${(s.:.)LS_COLORS}


### User configuration
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=50000
export SAVEHIST=10000

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/TeX/Distributions/.DefaultTeX/Contents/Programs/texbin:/usr/local/sbin:/usr/local/opt/mysql@5.6/bin"
# export PATH="/usr/local/opt/python/libexec/bin:$PATH" # brew's python before OSX's in PATH
# export MANPATH="/usr/local/man:$MANPATH"

# source $ZSH/oh-my-zsh.sh

source ~/.config/alias.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  #export EDITOR='mvim -v'
  export EDITOR='nvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#export JAVA_HOME=$(/usr/libexec/java_home -v 1.7)
# export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)

export BITBUCKET_USERNAME=cixel
export MYSQL_HOME=/usr/local/mysql

export MAVEN_HOME=/usr/local/bin/mvn
#export MAVEN_OPTS='-Xmx1g -XX:MaxPermSize=256m -Dcontrast.superadmin.key=demodemo'

# $ functionName server.js
function getNodeMemory() {
	ps -p $(pgrep -lfa node | grep "$1" | awk '{print $1}') -o rss,vsz
}
function watchNodeMemory() {
	top -pid $(pgrep -lfa node | grep "$1" | awk '{print $1}')
}

alias ack='ag --ignore-dir=node_modules --ignore-dir=labs --ignore-dir=docs --ignore-dir=dist --ignore-dir=code-coverage-report'

# Color scheme
#[[ $TMUX  = "" ]] && export TERM="xterm-256color"

export FZF_COMPLETION_TRIGGER='~~'
# Use fd (https://github.com/sharkdp/fd) instead of the default find
# command for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
# _fzf_compgen_path() {
#   fd --hidden --follow --exclude ".git" . "$1"
# }
# # Use fd to generate the list for directory completion
# _fzf_compgen_dir() {
#   fd --type d --hidden --follow --exclude ".git" . "$1"
# }
# FIXME: this is a stop-gap for until i have nix managing zsh
. ~/.nix-profile/share/fzf/key-bindings.zsh
. ~/.nix-profile/share/fzf/completion.zsh
# [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

#[[ -s "~/.gvm/scripts/gvm" ]] && source "~/.gvm/scripts/gvm"
export GOROOT_BOOTSTRAP="/usr/local/Cellar/go/1.12/libexec"
export GOPATH="$HOME/gopath/"
# export PATH=$PATH:/usr/local/opt/go/libexec/bin
# echo "please help lmao"
export PATH=$PATH:~/gopath/bin
export PATH=$PATH:~/go/bin
export PATH=$PATH:~/golang/bin
export PATH="$HOME/.cargo/bin:$PATH"
export RUST_SRC_PATH=$(rustc --print sysroot)/lib/rustlib/src/rust/src

bindkey '^[OA' up-line-or-search
bindkey '^[OB' down-line-or-search
#up-line-or-history = "^[OA"
#down-line-or-history= "^[OB"

# fixes for ctrl-h bug in tmux
#infocmp $TERM | sed 's/kbs=^[hH]/kbs=\\177/' > $TERM.ti
#tic $TERM.ti
#infocmp $TERM | sed 's/kbs=^[hH]/kbs=\\177/' | tic

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

source ~/.sensitive

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/ehdens/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/ehdens/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/ehdens/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/ehdens/google-cloud-sdk/completion.zsh.inc'; fi

export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
. /Users/ehdens/.nix-profile/etc/profile.d/nix.sh

eval "$(starship init zsh)"

# uncomment when startup time logging is enabled:
# zprof
# zmodload zsh/zprof

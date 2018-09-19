# uncomment to enable startup time logging
# zmodload zsh/zprof

# Path to your oh-my-zsh installation.
export ZSH=/Users/ehdensinai/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

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

export NVM_DIR=~/.nvm
export NVM_LAZY_LOAD=true
# source $(brew --prefix nvm)/nvm.sh --no-use

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git vi-mode node wd)
plugins=(git vi-mode wd zsh-nvm)

# User configuration

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/TeX/Distributions/.DefaultTeX/Contents/Programs/texbin:/usr/local/sbin:/usr/local/opt/mysql@5.6/bin"
# export PATH="/usr/local/opt/python/libexec/bin:$PATH" # brew's python before OSX's in PATH
# export MANPATH="/usr/local/man:$MANPATH"

source $ZSH/oh-my-zsh.sh

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
export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
alias setJDK6='export JAVA_HOME=$(/usr/libexec/java_home -v 1.6)'
alias setJDK7='export JAVA_HOME=$(/usr/libexec/java_home -v 1.7)'
alias setJDK8='export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)'

export BITBUCKET_USERNAME=cixel
export MYSQL_HOME=/usr/local/mysql

export MAVEN_HOME=/usr/local/bin/mvn
#export MAVEN_OPTS='-Xmx1g -XX:MaxPermSize=256m -Dcontrast.superadmin.key=demodemo'
#alias maven-teamserver='mvn clean verify -s ~/.m2/contrast-settings.xml -Develop -Pencrypt-properties -Dcontrast.superadmin.key=demodemo -DskipTests'
alias maven-teamserver='mvn clean verify -s ~/.m2/contrast-settings.xml -Develop -Ddevelop-debug -Dcargo.container.devargs="-Dcontrast.superadmin.key=demodemo" -Dmail.enabled=false -DskipTests -Dfmt.skip -Dcheckstyle.skip -Dcontrast.skip.copy.agents=true'
# alias maven-teamserver='mvn clean verify -s ~/.m2/contrast-settings.xml -Develop -Ddevelop-debug -Dcargo.container.devargs="-Dcontrast.superadmin.key=demodemo" -Dmail.enabled=false -Dcontrast.skip.copy.agents=true'
alias maven-teamserver-test='mvn -s ~/.m2/contrast-settings.xml -Pencrypt-properties clean compile tomcat:run-war'
alias maven-eclipse='mvn -s ~/.m2/contrast-settings.xml clean compile install'
alias maven-hub='cd /Users/ehdensinai/Documents/contrast-repos/hub/ && setJDK8 && mvn clean compile package tomcat:run -s ~/.contrast/contrast-settings.xml -Dcontrast.data.dir=/Users/ehdensinai/.hub -DskipTests'
# some things require settings from ~/.m2/contrast-settings.xml

#alias vim='mvim -v'
alias vim='nvim'
alias v='nvim'

alias tomcat='sh /Applications/apache-tomcat-7.0.56/bin/catalina.sh run'
alias webgoat-java-logging='java -javaagent:/Applications/apache-tomcat-7.0.56/contrast.jar -Dcontrast.level=debug -Dcontrast.log=/Users/ehdensinai/Desktop/contrast.log -jar /Applications/apache-tomcat-7.0.56/WebGoat-6.0.1-war-exec.jar'
alias webgoat-java='java -javaagent:/Applications/apache-tomcat-7.0.56/contrast.jar -jar /Applications/apache-tomcat-7.0.56/WebGoat-6.0.1-war-exec.jar'
alias webgoat-java-eclipse='java -javaagent:/Users/ehdensinai/Documents/workspaces/ticketbook/.metadata/.plugins/com.contrastsecurity.eclipse/.contrast/contrast-engine-3.1.6.jar -Dcontrast.noteamserver.enable=true -jar /Applications/apache-tomcat-7.0.56/WebGoat-6.0.1-war-exec.jar'

alias tmux='tmux -2'

# Node run configs
#alias contrast-screener='(cd ~/Documents/contrast-repos/node-screener/apps/node_express && DEBUG=contrast:* node-contrast run ~/Documents/contrast-repos/node-screener/apps/node_express/index.js)'
alias contrast-screener='cd ~/Documents/contrast-repos/node-screener/apps/node_express && DEBUG=contrast:* node-contrast ~/Documents/contrast-repos/node-screener/apps/node_express/index.js'
alias contrast-ghost='cd ~/Documents/tinkers/nodejs/ghost-0.6.4/ && nvm use 0.12.7 && DEBUG=contrast:* node-contrast ~/Documents/tinkers/nodejs/ghost-0.6.4/index.js'
alias contrast-ghost-debug='cd ~/Documents/tinkers/nodejs/ghost-0.6.4/ && nvm use 0.12.7 && DEBUG=contrast:* node-debug node-contrast ~/Documents/tinkers/nodejs/ghost-0.6.4/index.js'
#alias contrast-screener-debug='(cd ~/Documents/contrast-repos/node-screener/apps/node_express && DEBUG=contrast:* slc debug node-contrast run ~/Documents/contrast-repos/node-screener/apps/node_express/index.js)'
#alias contrast-screener-debug='cd ~/Documents/contrast-repos/node-screener/apps/node_express && DEBUG=contrast:* slc debug node-contrast run ~/Documents/contrast-repos/node-screener/apps/node_express/index.js'
alias contrast-screener-debug='cd ~/Documents/contrast-repos/node-screener/apps/node_express && DEBUG=contrast:* node-debug node-contrast ~/Documents/contrast-repos/node-screener/apps/node_express/index.js'
alias contrast-mocha='DEBUG=contrast:* /usr/local/lib/node_modules/mocha/bin/_mocha'
alias contrast-mocha-debug='DEBUG=contrast:* node-debug /usr/local/lib/node_modules/mocha/bin/_mocha'
alias reset-node-log='rm ~/node-contrast.log && touch ~/node-contrast.log'
export CONTRAST_DEBUG="1"

alias update-contrast-repos='cd ~/Documents/contrast-repos && find . -type d -depth 1 -exec git --git-dir={}/.git --work-tree=$PWD/{} pull \;'

alias delete-swaps='find ./ -type f -name "\.*sw[klmnop]" -delete'
# $ functionName server.js
function getNodeMemory() {
	ps -p $(pgrep -lfa node | grep "$1" | awk '{print $1}') -o rss,vsz
}
function watchNodeMemory() {
	top -pid $(pgrep -lfa node | grep "$1" | awk '{print $1}')
}

alias ack='ag --ignore-dir=node_modules --ignore-dir=labs --ignore-dir=docs --ignore-dir=dist'

# Color scheme
#[[ $TMUX  = "" ]] && export TERM="xterm-256color"
[[ $TMUX  = "" ]] && export TERM="screen-256color"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

#[[ -s "/Users/ehdensinai/.gvm/scripts/gvm" ]] && source "/Users/ehdensinai/.gvm/scripts/gvm"
export GOROOT_BOOTSTRAP="/usr/local/Cellar/go/1.10/libexec"
export GOPATH="$HOME/go/:$HOME/Documents/tinkers/go/:$HOME/Documents/contrast-repos/go"
# export PATH=$PATH:/usr/local/opt/go/libexec/bin
export PATH=$PATH:/Users/ehdensinai/go/bin
export PATH=$PATH:/Users/ehdensinai/golang/bin
export PATH="$HOME/.cargo/bin:$PATH"
export RUST_SRC_PATH="/Users/ehdensinai/.cargo/registry/src"

bindkey '^[OA' up-line-or-search
bindkey '^[OB' down-line-or-search
#up-line-or-history = "^[OA"
#down-line-or-history= "^[OB"

# fixes for ctrl-h bug in tmux
#infocmp $TERM | sed 's/kbs=^[hH]/kbs=\\177/' > $TERM.ti
#tic $TERM.ti
#infocmp $TERM | sed 's/kbs=^[hH]/kbs=\\177/' | tic

alias gitlines="git ls-files | xargs wc -l"
alias find_people='ifconfig | grep broadcast | arp -a'
alias hide_desktop='defaults write com.apple.finder CreateDesktop false' # set true to reenable

alias rw='/Users/ehdensinai/Documents/contrast-repos/i13n/rw'

# https://theptrk.com/2018/07/11/did-txt-file/
alias did="vim +'normal Go' +'r!date' ~/did.txt"

# uncomment to enable startup time logging
# zprof

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/ehdensinai/google-cloud-sdk/path.zsh.inc' ]; then source '/Users/ehdensinai/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/ehdensinai/google-cloud-sdk/completion.zsh.inc' ]; then source '/Users/ehdensinai/google-cloud-sdk/completion.zsh.inc'; fi

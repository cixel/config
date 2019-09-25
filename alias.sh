alias setJDK6='export JAVA_HOME=$(/usr/libexec/java_home -v 1.6)'
alias setJDK7='export JAVA_HOME=$(/usr/libexec/java_home -v 1.7)'
alias setJDK8='export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)'

#alias maven-teamserver='mvn clean verify -s ~/.m2/contrast-settings.xml -Develop -Pencrypt-properties -Dcontrast.superadmin.key=demodemo -DskipTests'
alias maven-teamserver='mvn clean verify -s ~/.m2/contrast-settings.xml -Develop -Ddevelop-debug -Dcargo.container.devargs="-Dcontrast.superadmin.key=demodemo" -Dmail.enabled=false -DskipTests -Dfmt.skip -Dcheckstyle.skip -Dcontrast.skip.copy.agents=true'
# alias maven-teamserver='mvn clean verify -s ~/.m2/contrast-settings.xml -Develop -Ddevelop-debug -Dcargo.container.devargs="-Dcontrast.superadmin.key=demodemo" -Dmail.enabled=false -Dcontrast.skip.copy.agents=true'
alias maven-teamserver-test='mvn -s ~/.m2/contrast-settings.xml -Pencrypt-properties clean compile tomcat:run-war'
alias maven-eclipse='mvn -s ~/.m2/contrast-settings.xml clean compile install'
alias maven-hub='cd ~/Documents/contrast-repos/hub/ && setJDK8 && mvn clean compile package tomcat:run -s ~/.contrast/contrast-settings.xml -Dcontrast.data.dir=~/.hub -DskipTests'
# some things require settings from ~/.m2/contrast-settings.xml


#alias vim='mvim -v'
alias vim='nvim'
alias v='nvim'

alias tomcat='sh /Applications/apache-tomcat-7.0.56/bin/catalina.sh run'
alias webgoat-java-logging='java -javaagent:/Applications/apache-tomcat-7.0.56/contrast.jar -Dcontrast.level=debug -Dcontrast.log=~/Desktop/contrast.log -jar /Applications/apache-tomcat-7.0.56/WebGoat-6.0.1-war-exec.jar'
alias webgoat-java='java -javaagent:/Applications/apache-tomcat-7.0.56/contrast.jar -jar /Applications/apache-tomcat-7.0.56/WebGoat-6.0.1-war-exec.jar'
alias webgoat-java-eclipse='java -javaagent:~/Documents/workspaces/ticketbook/.metadata/.plugins/com.contrastsecurity.eclipse/.contrast/contrast-engine-3.1.6.jar -Dcontrast.noteamserver.enable=true -jar /Applications/apache-tomcat-7.0.56/WebGoat-6.0.1-war-exec.jar'

alias tmux='tmux -2'

alias update-contrast-repos='cd ~/Documents/contrast-repos && find . -type d -depth 1 -exec git --git-dir={}/.git --work-tree=$PWD/{} pull \;'

alias delete-swaps='find ./ -type f -name "\.*sw[klmnop]" -delete'

alias gitlines="git ls-files | xargs wc -l"
alias find_people='ifconfig | grep broadcast | arp -a'
alias hide_desktop='defaults write com.apple.finder CreateDesktop false' # set true to reenable

# https://theptrk.com/2018/07/11/did-txt-file/
alias did="vim +'normal Go' +'r!date' ~/did.txt"

alias gd="go doc"
alias gdu="go doc -u"

# from ~/.oh-my-zsh/lib/directories.zsh
# Changing/making/removing directory
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

alias -- -='cd -'
alias 1='cd -'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

alias md='mkdir -p'
alias rd=rmdir
alias d='dirs -v | head -10'

# List directory contents
alias lsa='ls -lah'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'

alias hm=home-manager

alias l='exa -la'

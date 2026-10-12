# General-purpose aliases

alias ls='ls --color=auto'
alias l='ls'
alias ls.='ls -a'
alias ll='ls -l'
alias l.='ls -d .*'
alias lt='ls -ltr'
alias ll.='ls -la'
alias lt.='ls -latr'

# herpderp
alias damnit='sudo $(history -p \!\!)'

## get rid of command not found ##
alias cd..='cd ..'

## a quick way to get out of current directory ##
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'

## Colorize the grep command output for ease of use (good for log files)##
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Calculator with math support
alias bc='bc -l'

# sha1
alias sha1='openssl sha1'

# Auto-create parent directories
alias mkdir='mkdir -pv'

# install  colordiff package :)
if command -v colordiff >/dev/null 2>&1; then
    alias diff='colordiff'
fi

# handy short cuts #
alias h='history'
alias j='jobs -l'

# Print current PATH
alias path='echo -e ${PATH//:/\\n}'

# date stuff
alias now='date +"%T"'
alias nowtime=now
alias nowdate='date +"%d-%m-%Y"'
alias epoch='date +%s'

# ViMproved
if command -v vim >/dev/null 2>&1; then
    alias vi=vim
    alias svi='sudo vi'
    alias vis='vim "+set si"'
    alias edit='vim'
fi

# get web server headers #
alias header='curl -I'

# find out if remote server supports gzip / mod_deflate or not #
alias headerc='curl -I --compress'

# do not delete / or prompt if deleting more than 3 files at a time #
alias rm='rm -I --preserve-root'

# Preventing changing perms on / #
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'

## this one saved by butt so many times -- auto-resume wget! ##
alias wget='wget -c'

## set some other defaults ##
alias df='df -H'
alias du='du -ch'

## pass options to free ##
alias meminfo='free -m -l -t'

## get top process eating memory
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'

## get top process eating cpu ##
alias pscpu='ps auxf | sort -nr -k 3'
alias pscpu10='ps auxf | sort -nr -k 3 | head -10'

## Get server cpu info ##
alias cpuinfo='lscpu'

# top is atop, just like vi is vim
if command -v htop >/dev/null 2>&1; then
    alias top='htop'
fi

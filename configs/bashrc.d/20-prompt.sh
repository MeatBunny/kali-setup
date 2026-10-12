# Prompt colors, PS1 and terminal title helpers

# Bash Color Variables
cb='\[\033['; ce='\]'; def="${cb}0m${ce}"
blk="${cb}30m${ce}" ; red="${cb}31m${ce}"
grn="${cb}32m${ce}"; ylw="${cb}33m${ce}"
blu="${cb}34m${ce}"; mag="${cb}35m${ce}"
cyn="${cb}36m${ce}"; gry="${cb}90m${ce}"
lred="${cb}91m${ce}"; lgrn="${cb}92m${ce}"
lylw="${cb}93m${ce}"; lblu="${cb}94m${ce}"
lmag="${cb}95m${ce}"; lcyn="${cb}96m${ce}"
lgry="${cb}37m${ce}"
# Okabe-Ito colorblind-safe truecolor (needs a 24-bit terminal)
org="${cb}38;2;230;159;0m${ce}"; sky="${cb}38;2;86;180;233m${ce}"
gld="${cb}38;2;255;215;0m${ce}"
vrm="${cb}38;2;213;94;0m${ce}"; bgrn="${cb}38;2;0;158;115m${ce}"
export PS1="${vrm}\t${def} ${bgrn}\H${def}:${sky}\w${def}\\$ "

ps1rename () {
    if [[ $1 == 'bw' ]]; then
        export PS1="\t [${@:2}]\\$ "
        # unalias colorful aliases
        unalias ls grep egrep fgrep diff 2>/dev/null
    else 
        export PS1="${vrm}\t${def} ${sky}[${@}]${def}\\$ "
    fi
}

title() {
    printf '\033]0;%s\a' "$*"
}

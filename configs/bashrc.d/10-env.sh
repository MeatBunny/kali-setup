# Environment, history, PATH

export PAGER=less
export SYSTEMD_PAGER=less
export HISTSIZE=10000
export HISTFILESIZE=10000

# Fix lines
shopt -s checkwinsize

if [[ -f $HOME/.mypath ]]; then
    source $HOME/.mypath
else
    export PATH="$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
fi
if [[ -d $HOME/bin ]]; then
    export PATH="$PATH:$HOME/bin"
fi

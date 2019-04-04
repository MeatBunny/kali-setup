#!/bin/bash

##############################################
#                                           #
#  A simple Kali setup script.              #
#                                           #
#  curl -Lo setup.sh https://bit.ly/2IO6kKN #
#  bash setup.sh -h                         #
#                                           #
#  Don't @ me.                              #
#                                           #
#############################################

usage () {
    echo -e "\e[94m$0 [-d] [-p] [-r] [-l] [-g] [-v]\e[0m"
    echo -e "\t-d Don't install any docker containers."
    echo -e "\t-p Don't install PTF."
    echo -e "\t-r Don't install PUPY RAT."
    echo -e "\t-l Don't setup root to log in automatically."
    echo -e "\t-g Don't clone select repos from github to /opt."
    echo -e "\t-v Verbose"
    echo -e "\t-h This message"
    exit 1
}

debug () {
    if [[ $_verbose ]]; then
        echo -e "\e[92mDebug:  $1\e[0m"
        sleep 1
    fi
}

warn () {
    echo -e "\e[93mWARNING:  $1\e[0m"
    sleep 1
}

# Variables and settings
# Case insensitive matching for regex
shopt -s nocasematch
# (Try to) stop apt from asking stupid questions
export DEBIAN_FRONTEND=noninteractive
# Packages to install after update.
_aptpackages="open-vm-tools-desktop vim htop veil-* docker.io terminator git libssl1.0-dev libffi-dev python-dev python-pip tcpdump python-virtualenv"
_githubclone="chokepoint/azazel gaffe23/linux-inject nathanlopez/Stitch mncoppola/suterusu nurupo/rootkit"
_dockercontainers="alxchk/pupy:unstable empireproject/empire kalilinux/kali-linux-docker python"

unset _skipdocker _skipptf _skippupyrat _skipautologin _skipgithub _verbose
while getopts 'hdprlgv' flag; do
    case "${flag}" in
        d) _skipdocker=1 ;;
        p) _skipptf=1 ;;
        r) _skippupyrat=1 ;;
        l) _skipautologin=1 ;;
        g) _skipgithub=1 ;;
        v) _verbose=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

if ! [[ $_skipautologin ]]; then
    debug "Setting up root to automatically log in."
    sed -i "s/^#.*AutomaticLoginEnable/AutomaticLoginEnable/g ; s/#.*AutomaticLogin/AutomaticLogin/g" /etc/gdm3/daemon.conf
fi

if ! [[ -f ~/.updated ]]; then
    debug "Removing built in SSH keys"
    rm -vf /etc/ssh/ssh_host_*
    dpkg-reconfigure openssh-server
    debug "Updating everything.  Killing packagekitd in the background."
    pgrep packagekitd | xargs kill 2>/dev/null
    sleep 1
    debug "Updating repos."
    apt-get -q update
    debug "Updating installed packages."
    apt-get -q dist-upgrade -y
    debug "Installing the below packages:"
    debug "$_aptpackages"
    apt-get -q install -y $_aptpackages
    debug "Autoremoving things we don't need anymore."
    apt-get -q autoremove -y
    debug "Checking to see if we need to reboot after the update due to a new kernel."
    touch ~/.updated
fi

_running=$(uname -r)
_ondisk=$(dpkg --list | awk '/linux-image-[0-9]+/ {print $2}' | sort -V | tail -1)
if ! [[ $_ondisk == *${_running}* ]]; then
    warn "Looks like the running kernel ($_running) doesn't match the on disk kernel ($_ondisk) after the update."
    echo "You're probably going to want to reboot and run this script again to avoid errors with PTF."
    read -p "Reboot? [yN]"
    if [[ ${REPLY,,} =~ ^y ]]; then
        reboot
    fi
else
    debug "Looks good ... continuing."
fi

if ! [[ $_skipgithub ]]; then
    debug "Set up non-ptf git repos"
    pushd /opt
    for _repo in $_githubclone; do
        _dir=$(echo $_repo | cut -d'/' -f2)
        if ! [[ -d $_dir ]]; then
            git clone https://github.com/$_repo.git
        else
            pushd $_dir
            git pull
            popd
        fi
    done
    popd
fi

if ! [[ $_skipptf ]]; then
    debug "Grabbing PTF from github."
    git clone  https://github.com/trustedsec/ptf /opt/ptf
    cat << EOF > /opt/ptf/config/ptf.config
BASE_INSTALL_PATH="/opt"
LOG_PATH="src/logs/ptf.log"
AUTO_UPDATE="ON"
IGNORE_THESE_MODULES=""
INCLUDE_ONLY_THESE_MODULES="modules/pivoting/3proxy,modules/webshells/b374k,modules/powershell/babadook,modules/powershell/bloodhound,modules/post-exploitation/empire,modules/powershell/empire,modules/post-exploitation/creddump7,modules/pivoting/meterssh,modules/windows-tools/netripper,modules/pivoting/pivoter,modules/pivoting/rpivot,modules/windows-tools/sidestep,modules/webshells/*"
IGNORE_UPDATE_ALL_MODULES=""
EOF
    debug "Set up PTF.  PTF requires --update-all to be run in its working directory."
    pushd /opt/ptf
    echo -en "use modules/install_update_all\nyes\n" | python ptf
    popd
fi

if ! [[ $_skipdocker ]]; then
    debug "Set up docker"
    mkdir /etc/docker/
    echo -e '{\n\t"iptables": false\n}' > /etc/docker/daemon.json
    systemctl enable docker
    systemctl stop docker
    systemctl daemon-reload
    systemctl start docker
    for _image in $_dockercontainers; do
        docker pull $_image
    done
fi

if ! [[ $_skippupyrat ]]; then
    debug "Set up Pupy correctly"
    pushd /opt
    git clone --recursive https://github.com/n1nj4sec/pupy
    pushd pupy
    python create-workspace.py -DG pupyw
    wget https://github.com/n1nj4sec/pupy/releases/download/latest/payload_templates.txz
    tar xvf payload_templates.txz && mv payload_templates/* pupy/payload_templates/ && rm payload_templates.txz && rm -r payload_templates
    popd
    popd
fi

debug "Misc Kali commands"
debug "MSFDB init"
msfdb init
msfdb start

debug "Update mlocate"
updatedb

rm -vf ~/.updated

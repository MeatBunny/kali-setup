#!/bin/bash

#####################################
#                                   #
#   A simple Kali setup script.     #
#                                   #
#   Don't @ me.                     #
#                                   #
#####################################

# Variables and settings
# Case insensitive matching for regex
shopt -s nocasematch
# Packages to install after update.
_aptpackages="open-vm-tools-desktop vim htop veil-*"
_githubclone="chokepoint/azazel gaffe23/linux-inject nathanlopez/Stitch mncoppola/suterusu nurupo/rootkit trustedsec/ptf"
_dockercontainers="alxchk/pupy:unstable empireproject/empire"

# Update all 
if ! [[ -f ~/.updated ]]; then
    echo "Updating everything"
    sleep 1
    apt-get update && \
    apt-get dist-upgrade -y && \
    touch ~/.updated
    apt-get install -y $_aptpackages
    read -p "Reboot? [yN]"
    if [[ ${REPLY,,} =~ ^y ]]; then
        reboot
    fi
fi

# Set up non-ptf git repos
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

# Set up PTF.  PTF requires --update-all to be run in its working directory.
cat ptf.config > /opt/ptf/ptf.config
pushd /opt/ptf
./ptf --update-all
popd

# Set up docker
mkdir /etc/docker/
echo '{ "iptables": false }' > /etc/docker/daemon.json
apt-get install -y docker.io
systemctl enable docker
systemctl stop docker
systemctl daemon-reload
systemctl start docker

# Misc Kali commands
# MSFDB init
msfdb init
msfdb start

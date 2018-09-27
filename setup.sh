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

# Install Docker
echo "Installing Docker"
(curl -fsSL https://get.docker.com | bash) || exit 1

pushd /opt
for _repo in $_githubclone; do
    git clone https://github.com/$_repo.git
done
popd

cat ptf.config > /opt/ptf/ptf.config
/opt/ptf/ptf --update-all

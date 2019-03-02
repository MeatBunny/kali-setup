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
_aptpackages="open-vm-tools-desktop vim htop veil-* docker.io terminator git libssl1.0-dev libffi-dev python-dev python-pip tcpdump python-virtualenv"
_githubclone="chokepoint/azazel gaffe23/linux-inject nathanlopez/Stitch mncoppola/suterusu nurupo/rootkit trustedsec/ptf"
_dockercontainers="alxchk/pupy:unstable empireproject/empire"

# Update all 
if ! [[ -f ~/.updated ]]; then
    echo "Updating everything"
    pgrep packagekitd | xargs kill
    sleep 1
    apt-get update && \
    apt-get dist-upgrade -y && \
    touch ~/.updated
    apt-get install -y $_aptpackages
    _runningkernel=`uname -r`
    _ondiskkernel=`dpkg --list | grep -v 'meta-package' | tail -1 | grep -oP '\d\.\d{1,2}.\d{1,2}-kali(\d{1,2})-amd64'`
    if ! [[ "$_runningkernel" == "$_ondiskkernel" ]]; then
        echo "Looks like the running kernel ($runningkernel) doesn't match the on disk kernel ($_ondiskkernel)."
        read -p "Reboot? [yN]"
        if [[ ${REPLY,,} =~ ^y ]]; then
            reboot
        fi
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
cat << EOF > /opt/ptf/config/ptf.config
BASE_INSTALL_PATH="/opt"
LOG_PATH="src/logs/ptf.log"
AUTO_UPDATE="ON"
IGNORE_THESE_MODULES=""
INCLUDE_ONLY_THESE_MODULES="modules/pivoting/3proxy,modules/webshells/b374k,modules/powershell/babadook,modules/powershell/bloodhound,modules/post-exploitation/empire,modules/powershell/empire,modules/post-exploitation/creddump7,modules/pivoting/meterssh,modules/windows-tools/netripper,modules/pivoting/pivoter,modules/pivoting/rpivot,modules/windows-tools/sidestep,modules/webshells/*"
IGNORE_UPDATE_ALL_MODULES=""
EOF
pushd /opt/ptf
./ptf --update-all
popd

# Set up docker
mkdir /etc/docker/
echo -e '{\n\t"iptables": false\n}' > /etc/docker/daemon.json
systemctl enable docker
systemctl stop docker
systemctl daemon-reload
systemctl start docker
for _image in $_dockercontainers; do
    docker pull $_image
done

# Set up Pupy correctly
pushd /opt
git clone --recursive https://github.com/n1nj4sec/pupy
pushd pupy
python create-workspace.py -DG pupyw
wget https://github.com/n1nj4sec/pupy/releases/download/latest/payload_templates.txz
tar xvf payload_templates.txz && mv payload_templates/* pupy/payload_templates/ && rm payload_templates.txz && rm -r payload_templates
popd
popd

# Misc Kali commands
# MSFDB init
msfdb init
msfdb start

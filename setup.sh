#!/bin/bash

#############################################
#                                           #
#  My excessive Kali setup script.          #
#                                           #
#  curl -Lo setup.sh https://bit.ly/2IO6kKN #
#                                           #
#  Don't @ me. Change the SSH key if        #
#  you want to use this.                    #
#                                           #
#############################################

usage () {
    echo -e "\e[94m$0 [-d] [-p] [-r] [-l] [-g] [-v]\e[0m"
    echo -e "\t-d Don't install any docker containers."
    echo -e "\t-p Don't install PTF."
    echo -e "\t-r Don't install PUPY RAT."
    echo -e "\t-l Don't setup root to log in automatically."
    echo -e "\t-g Don't clone select repos from github to /opt."
    echo -e "\t-s Don't add my SSH key to authorized keys."
    echo -e "\t-k FILE Use FILE as the SSH private key."
    echo -e "\t-u Don't create a unprivilieged browser user."
    echo -e "\t-c Don't update config dotfiles (vim, terminator, etc)."
    echo -e "\t-q Don't show debug messages"
    echo -e "\t-h This message"
    exit 1
}

debug () {
    if [[ $_verbose -eq 1 ]]; then
        echo -e "\e[92mDebug:  $1\e[0m"
        sleep 1
    fi
}

warn () {
    echo -e "\e[93mWARNING:  $1\e[0m"
    # Sometimes commands are going to fail and not be fatal, so instead of set -e do this on important things.
    if [[ $2 =~ exitnow ]]; then
        exit 1
    fi
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
_verbose=1
_mykey='ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEA1qFirNw2tXsU+FWepT7goKmBYWF1WhxQwyQB6k70K3T0jbJuakzLRE1YRWCeD8u/icGHBBGdmiur7EUoqzUdzxVP+Fq7v0d+o1ZM+xXCnCeygfOghTyhoL23T+O+g3MvQj4UcSvoRSS6blwdpsiPWIZyqpNoeLG+kej/pJ7y3njHsGLAtFjUHE4B6RQrDPwCO36vmBE+cD0ylzKHajHS45jCxgzHs1ZrvztsrnI58YjVZ3Od6O8Sb6ME0jaHeqF1w4PlwCkVg30OAzubGNMt9s1aYt8Ce1poqRiMaUgM8c6WMYbCzvUqdHNCxRVcz8z2iPjXWvJjchE0v8qUeobmS/05glqI7QRmA/gzIpV+n8MKGh0vNr+5XuVOpw0aj1c0kLYrJRbrkZEg8fIDBgEYmCaYsviDrNn6HnD3a14RYUN1UTytjXueI1dwx76ZI3Fxp9olXCI3rIUBaa8wPN/bkWYBvomr5qhKQ612vsm1IgOcYvO8LQeY/OaT50LnFGbb3Ut9erPsjv+pX3p6fkdvzixB0P9eliRW3JUSf/WjRs0ISdGGpUPT90SsnSJ4WpDx/K85kfcmG0ZiEPWW0aSOGgR6kfXSAbHK9V4c3v0KkSD1CuIb+aAv+4C/tAEuXavSqL0SbRMlLLuJlEhWoaZyoHOdPektHke2/JkkYKfZstk='
unset _skipdocker _skipptf _skippupyrat _skipautologin _skipgithub _skipauthkey _mykey _skipdotfiles _skipunpriv
while getopts 'hdprlgsk:cv' flag; do
    case "${flag}" in
        d) _skipdocker=1 ;;
        p) _skipptf=1 ;;
        r) _skippupyrat=1 ;;
        l) _skipautologin=1 ;;
        g) _skipgithub=1 ;;
        s) _skipauthkey=1 ;;
        k) if [[ -f ${OPTARG} ]]; then 
              _mykey="$(cat ${OPTARG})"
           else
              warn "${OPTARG} does not exist!"
              exit 1
           fi ;;
        c) _skipdotfiles=1 ;;
        q) _verbose=0 ;;
        u) _skipunpriv=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

if ! [[ -f ~/.firstrun ]]; then

    debug "Turning off power management, animations, and the screensaver."
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout '0'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout '0'
    gsettings set org.gnome.desktop.session idle-delay '0'
    gsettings set org.gnome.desktop.screensaver lock-enabled false
    gsettings set org.gnome.desktop.interface enable-animations false

    if ! [[ $_skipautologin ]]; then
        debug "Setting up root to automatically log in."
        sed -i "s/^#.*AutomaticLoginEnable/AutomaticLoginEnable/g ; s/#.*AutomaticLogin/AutomaticLogin/g" /etc/gdm3/daemon.conf
    fi

    debug "Removing built in SSH keys"
    rm -f /etc/ssh/ssh_host_*
    dpkg-reconfigure openssh-server > /dev/null

    debug "Updating everything.  Stopping packagekitd in the background."
    systemctl stop packagekit
    systemctl disable packagekit
    sleep 1
    # Sometimes a child processs from the auto update keeps running.
    fuser -s -k /var/lib/apt/lists/lock
    sleep 1
    # Piping apt output to null since the -q flag doesn't get passed to the underlying dpkg for some reason. STDERR should still show.
    debug "Updating repos."
    apt-get -o -yq update >/dev/null || warn "Error in apt-get update" exitnow
    debug "Updating installed packages.  This will take a while."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq dist-upgrade >/dev/null || warn "Error in updating installed packages." exitnow
    debug "Installing the below packages:"
    debug "$_aptpackages"
    debug "This will take a while."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq install $_aptpackages >/dev/null || warn "Error when trying to install new packages" exitnow
    debug "Autoremoving things we don't need anymore."
    apt-get -yq autoremove >/dev/null || warn "Error in autoremove." exitnow
    touch ~/.firstrun
fi

debug "Checking to see if we need to reboot after the update due to a new kernel."
_running=$(uname -r)
_ondisk=$(dpkg --list | awk '/linux-image-[0-9]+/ {print $2}' | sort -V | tail -1)
if [[ $_ondisk == *${_running}* ]]; then
    debug "Looks good ... continuing."
else
    warn "Looks like the running kernel ($_running) doesn't match the on disk kernel ($_ondisk) after the update."
    echo "You're probably going to want to reboot and run this script again to avoid errors with PTF."
    read -p "Reboot? [Y/n]"
    if [[ ${REPLY,,} =~ ^n ]]; then
        warn "Ok, if you say so ..."
    else
        reboot
    fi
fi

if ! [[ $_skipauthkey ]] && ! grep -q "$_mykey" /root/.ssh/authorized_keys; then
    mkdir /root/.ssh
    chmod 700 /root/.ssh
    echo "$_mykey" >> /root/.ssh/authorized_keys 
    chmod 600 /root/.ssh/authorized_keys
    sed -i 's,^#PermitRootLogin.*,PermitRootLogin prohibit-password,g' /etc/ssh/sshd_config
    systemctl enable ssh
    systemctl start ssh
fi

if ! [[ $_skipunpriv ]]; then
    debug "Adding a unprivileged user to do stuff like web browsing over X11 forwarding."
    _unprivpass=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1)
    useradd -c "Unpriviliged user" -m user
    echo $_unprivpass | passwd --stdin user
    echo -e "username: user\npassword: $_unprivpass" > /root/unprivcreds.txt
    chmod 600 /root/unprivcreds.txt
    if [[ -f /root/.ssh/authorized_keys ]]; then
        mkdir /home/user/.ssh
        chmod 700 /home/user/.ssh
        cp /root/.ssh/authorized_keys /home/user/.ssh/authorized_keys
        chmod 600 /home/user/.ssh/authorized_keys
        chown user:user /home/user/.ssh /home/user/.ssh/authorized_keys
    fi
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

if ! [[ $_skipdotfiles ]]; then
    debug "Update terminator config"
    mkdir .config/terminator
    cat << EOF > .config/terminator/config
[global_config]
  focus = mouse
[keybindings]
[profiles]
  [[default]]
    cursor_color = "#aaaaaa"
    font = Monospace 14
    show_titlebar = False
    scrollback_infinite = True
    use_system_font = False
    copy_on_selection = True
[layouts]
  [[default]]
    [[[window0]]]
      type = Window
      parent = ""
    [[[child1]]]
      type = Terminal
      parent = window0
[plugins]
EOF

    debug "Updating vimrc"
    cat << EOF > .vimrc
set tabstop=8
set expandtab
set shiftwidth=4
set softtabstop=4
set background=dark
syntax on
set nohlsearch
set mouse-=a
EOF
fi

debug "Misc Kali commands"
debug "MSFDB init"
msfdb init
msfdb start

debug "Update mlocate"
updatedb

rm -f ~/.firstrun

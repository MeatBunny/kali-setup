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
    echo -e "\t-s USER Install SSH Keys for USER from github https"
    echo -e "\t-u Don't create a unprivilieged browser user."
    echo -e "\t-c Don't update config dotfiles (vim, terminator, etc)."
    echo -e "\t-q Don't show debug messages"
    echo -e "\t-h This message"
    exit 1
}

debug () {
    if [[ $verbose -eq 1 ]]; then
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
aptpackages=(open-vm-tools-desktop vim htop veil-* docker.io terminator git libssl1.0-dev libffi-dev python-dev python-pip tcpdump python-virtualenv sshpass)
githubclone=(chokepoint/azazel gaffe23/linux-inject nathanlopez/Stitch mncoppola/suterusu nurupo/rootkit)
dockercontainers=(alxchk/pupy:unstable empireproject/empire kalilinux/kali-linux-docker python nginx)
verbose=1
unset skipdocker skipptf skippupyrat skipautologin skipgithub sshuser skipdotfiles skipunpriv
while getopts 'hdprlgs:cv' flag; do
    case "${flag}" in
        d) skipdocker=1 ;;
        p) skipptf=1 ;;
        r) skippupyrat=1 ;;
        l) skipautologin=1 ;;
        g) skipgithub=1 ;;
        s) sshuser=${OPTARG} ;;
        c) skipdotfiles=1 ;;
        q) verbose=0 ;;
        u) skipunpriv=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -f ~/.firstrun ]]; then
    debug "Looks like we rebooted after a kernel update... not running initial updates."
else
    debug "Turning off power management, animations, and the screensaver."
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout '0'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout '0'
    gsettings set org.gnome.desktop.session idle-delay '0'
    gsettings set org.gnome.desktop.screensaver lock-enabled false
    gsettings set org.gnome.desktop.interface enable-animations false

    if ! [[ $skipautologin ]]; then
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
    apt-get -yq update >/dev/null || warn "Error in apt-get update" exitnow
    debug "Updating installed packages.  This will take a while."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq dist-upgrade >/dev/null || warn "Error in updating installed packages." exitnow
    debug "Installing the below packages:"
    debug "${aptpackages[@]}"
    debug "This will take a while."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq install ${aptpackages[@]} >/dev/null || warn "Error when trying to install new packages" exitnow
    debug "Autoremoving things we don't need anymore."
    apt-get -yq autoremove >/dev/null || warn "Error in autoremove." exitnow
    touch ~/.firstrun
fi

debug "Checking to see if we need to reboot after the update due to a new kernel."
running=$(uname -r)
ondisk=$(dpkg --list | awk '/linux-image-[0-9]+/ {print $2}' | sort -V | tail -1)
if [[ $ondisk == *${running}* ]]; then
    debug "Looks good ... continuing."
else
    warn "Looks like the running kernel ($running) doesn't match the on disk kernel ($ondisk) after the update."
    echo "You're probably going to want to reboot and run this script again to avoid errors with PTF."
    read -p "Reboot? [Y/n]"
    if [[ ${REPLY,,} =~ ^n ]]; then
        warn "Ok, if you say so ..."
    else
        reboot
    fi
fi

if [[ $sshuser ]]; then
    debug "Adding $sshuser 's github keys."
    mkdir /root/.ssh
    chmod 700 /root/.ssh
    curl -s https://github.com/${sshuser}.keys > /root/.ssh/authorized_keys || exit 1
    chmod 600 /root/.ssh/authorized_keys
    sed -i 's,^#PermitRootLogin.*,PermitRootLogin prohibit-password,g' /etc/ssh/sshd_config
    systemctl enable ssh
    systemctl start ssh
fi

if [[ $skipunpriv ]]; then
    debug "Skipping adding an unprivileged user"
else
    debug "Adding an unprivileged user to do stuff like web browsing over X11 forwarding."
    unprivpass=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1)
    useradd -c "Unpriviliged user" -m -s /bin/bash user
    echo "user:$unprivpass" | chpasswd
    echo -e "username: user\npassword: $unprivpass\n\nsshpass -p $unprivpass ssh -X user@127.0.0.1" > /root/unprivcreds.txt
    chmod 600 /root/unprivcreds.txt
    if [[ -f /root/.ssh/authorized_keys ]]; then
        mkdir /home/user/.ssh
        chmod 700 /home/user/.ssh
        cp /root/.ssh/authorized_keys /home/user/.ssh/authorized_keys
        chmod 600 /home/user/.ssh/authorized_keys
        chown user:user /home/user/.ssh /home/user/.ssh/authorized_keys
    fi
fi

if [[ $skipgithub ]]; then
    debug "Not pulling select repos from github."
else
    debug "Set up non-ptf git repos"
    pushd /opt
    for repo in "${githubclone[@]}"; do
        dir=$(echo $repo | cut -d'/' -f2)
        if [[ -d $dir ]]; then
            pushd $dir
            git pull
            popd
        else
            git clone https://github.com/$repo.git
        fi
    done
    popd
fi

if [[ $skipptf ]]; then
    debug "Skipping PTF install."
else
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

if [[ $skipdocker ]]; then
    debug "Skipping docker"
else
    debug "Set up docker"
    mkdir /etc/docker/
    echo -e '{\n\t"iptables": false\n}' > /etc/docker/daemon.json
    systemctl enable docker
    systemctl stop docker
    systemctl daemon-reload
    systemctl start docker
    for image in ${dockercontainers[@]}; do
        docker pull $image
    done
fi

if [[ $skippupyrat ]]; then
    debug "Not setting up pupy."
else
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

if [[ $skipdotfiles ]]; then
    debug "Skipping setting up dotfiles."
else
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

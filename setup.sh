#!/bin/bash

#############################################
#                                           #
#  My excessive Kali setup script.          #
#                                           #
#  curl -Lo setup.sh https://bit.ly/2IO6kKN #
#                                           #
#  Don't @ me.                              #
#                                           #
#############################################

usage () {
    echo -e "\e[94m$0 [-d] [-p] [-r] [-l] [-g] [-s]\e[0m"
    echo -e "\t-d Don't install any docker containers."
    echo -e "\t-p Don't install PTF."
    echo -e "\t-l Don't setup root to log in automatically."
    echo -e "\t-g Don't clone select repos from github to /opt."
    echo -e "\t-s USER Install SSH Keys for USER from github.com."
    echo -e "\t-c Don't update config dotfiles (vim, terminator, etc)."
    echo -e "\t-f Instead of this repo's dotfiles, pull 'dotfiles' from github user and run setup.sh if it exists."
    echo -e "\t-u Set the automatic login user.  Defaults to kali (if present) or root."
    echo -e "\t-b Skip pulling Exploit Database's Binary Exploits."
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

if [[ $EUID -ne 0 ]]; then
    warn "This script needs to be run as root." exitnow
fi

# Variables and settings
# Case insensitive matching for regex
shopt -s nocasematch
# (Try to) stop apt from asking stupid questions
export DEBIAN_FRONTEND=noninteractive
# Packages to install after update.
aptpackages=(vim htop veil-* docker.io terminator git libssl1.0-dev libffi-dev python-dev python-pip tcpdump python-virtualenv sshpass xterm colordiff)
githubclone=(chokepoint/azazel gaffe23/linux-inject nathanlopez/Stitch mncoppola/suterusu nurupo/rootkit m0nad/Diamorphine)
dockercontainers=(kalilinux/kali-linux-docker python nginx ubuntu:latest)
verbose=1
# Grabbing last match to prevent false positives.
desktopenvironment=$(ps -A | egrep -o 'gnome|kde|mate|cinnamon' | tail -1)
unset skipdocker skipptf skipautologin skipgithub sshuser skipdotfiles skipunpriv skipbinsploits
while getopts 'hdplgs:cfbq' flag; do
    case "${flag}" in
        d) skipdocker=1 ;;
        p) skipptf=1 ;;
        l) skipautologin=1 ;;
        g) skipgithub=1 ;;
        s) sshuser=${OPTARG} ;;
        c) skipdotfiles=1 ;;
        f) githubdotfiles=1 ;;
        b) skipbinsploits=1 ;;
        q) verbose=0 ;;
        u) autologinuser=${OPTARG} ;;
        h) usage ;;
        *) usage ;;
    esac
done

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if ! [[ -d $scriptdir/configs ]]; then
    scriptdir=$(mktemp -d -p /dev/shm)
    debug "Didn't detect config files.  Cloning git repo to temp directory."
    git clone https://github.com/MeatBunny/kali-setup.git $scriptdir
fi

if ! [[ $autologinuser ]] && grep -q 'kali' /etc/passwd; then
    autologinuser=kali
elif ! [[ $autologinuser ]] && ! grep -q 'kali' /etc/passwd; then
    autologinuser=root
elif [[ $autologinuser ]] && ! grep -q "$autologinuser" /etc/passwd; then
    warn "Automatic login user of $autologinuser not detected." exitnow
fi

if [[ -f ~/.firstrun ]]; then
    debug "Looks like we rebooted after a kernel update... not running initial updates."
else
    if [[ $autologinuser != "root" ]]; then
        debug "Setting up passwordless sudo for the sudo group."
        sed -i 's/.*%sudo.*/%sudo         ALL = (ALL) NOPASSWD: ALL/g' /etc/sudoers
    fi
    if [[ $desktopenvironment == "gnome" ]]; then
        debug "Turning off power management, animations, and the screensaver."
        sudo -u $autologinuser gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
        sudo -u $autologinuser gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout '0'
        sudo -u $autologinuser gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
        sudo -u $autologinuser gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout '0'
        sudo -u $autologinuser gsettings set org.gnome.desktop.session idle-delay '0'
        sudo -u $autologinuser gsettings set org.gnome.desktop.screensaver lock-enabled false
        sudo -u $autologinuser gsettings set org.gnome.desktop.interface enable-animations false
        if ! [[ $skipautologin ]]; then
            debug "Setting up $autologinuser to automatically log in."
            sed -i "s/^#.*AutomaticLoginEnable/AutomaticLoginEnable/g ; s/#.*AutomaticLogin .*/AutomaticLogin = $autologinuser/g" /etc/gdm3/daemon.conf
        fi
    fi

    debug "Removing built in SSH keys"
    rm -f /etc/ssh/ssh_host_*
    dpkg-reconfigure openssh-server > /dev/null

    debug "Updating everything.  Stopping packagekitd for some releases of Kali."
    systemctl stop packagekit
    systemctl disable packagekit
    # Sometimes a child processs from the auto update keeps running.
    if [[ -f /var/lib/apt/lists/lock ]]; then
        sleep 1
        fuser -s -k /var/lib/apt/lists/lock
        sleep 1
    fi
    # Piping apt output to null since the -q flag doesn't get passed to the underlying dpkg for some reason. STDERR should still show.
    debug "Updating repos."
    apt-get -yq update >/dev/null || warn "Error in apt-get update" exitnow
    debug "Updating installed packages.  This will take a while."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq dist-upgrade >/dev/null || warn "Error in updating installed packages." exitnow
    debug "Installing packages, this will take a while."
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
    debug "Adding ${sshuser}'s github keys."
    mkdir /root/.ssh /home/$autologinuser/.ssh
    chmod 700 /root/.ssh /home/$autologinuser/.ssh
    curl -s https://github.com/${sshuser}.keys > /root/.ssh/authorized_keys || exit 1
    cp /root/.ssh/authorized_keys /home/$autologinuser/.ssh/
    chmod 600 /root/.ssh/authorized_keys /home/$autologinuser/.ssh/authorized_keys
    chown $autologinuser:$autologinuser /home/$autologinuser/.ssh /home/$autologinuser/.ssh/authorized_keys
    sed -i 's,.*PermitRootLogin.*,PermitRootLogin prohibit-password,g ; s,.*ChallengeResponseAuthentication.*,ChallengeResponseAuthentication no,g ; s,.*PasswordAuthentication.*,PasswordAuthentication no,g' /etc/ssh/sshd_config
    systemctl enable ssh
    systemctl start ssh
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
    cp $scriptdir/configs/ptf_config /opt/ptf/config/ptf.config
    debug "Set up PTF.  PTF requires --update-all to be run in its working directory."
    pushd /opt/ptf
    echo -en "use modules/install_update_all\nyes\n" | python3 ptf
    popd
fi

if [[ $skipdocker ]]; then
    debug "Skipping docker"
else
    debug "Set up docker"
    systemctl enable docker
    systemctl stop docker
    systemctl daemon-reload
    systemctl start docker
    for image in ${dockercontainers[@]}; do
        docker pull $image
    done
fi

if [[ $skipbinsploits ]]; then
    debug "Skipping pulling binary exploits."
else
    git clone https://github.com/offensive-security/exploit-database-bin-sploits/ /opt/bin-sploits/
fi

if [[ $githubdotfiles ]]; then
    # git throws a hissy fit for some reason when run as root.
    debug "Fixing permissions for script directory $scriptdir"
    chown -R root:$autologinuser $scriptdir
    chmod 770 $scriptdir
    debug "Pulling dotfiles from ${sshuser}.  Adding ssh-keys."
    sudo -u $autologinuser $scriptdir/dotfile-clone.sh $autologinuser $sshuser
elif [[ $skipdotfiles ]]; then
    debug "Skipping setting up dotfiles."
else
    debug "Updating dotfiles."
    mkdir -p /root/.config/terminator
    cp $scriptdir/configs/terminator_config /root/.config/terminator/config
    cp $scriptdir/configs/bash_aliases /root/.bash_aliases
    echo 'source /root/.bash_aliases' >> /root/.bashrc
    cp $scriptdir/configs/vimrc /root/.vimrc
    if [[ $autologinuser != "root" ]]; then
        mkdir -p /home/${autologinuser}/.config/terminator
        cp $scriptdir/configs/terminator_config /home/${autologinuser}/.config/terminator/config
        cp $scriptdir/configs/vimrc /home/${autologinuser}/.vimrc
        cp $scriptdir/configs/bash_aliases /home/${autologinuser}/.bash_aliases
        chown -R $autologinuser:$autologinuser /home/${autologinuser}/.config/ /home/${autologinuser}/.vimrc /home/${autologinuser}/.bash_aliases
    fi
fi

debug "Misc Kali commands"
debug "MSFDB init"
msfdb init
msfdb start
echo -e '#!/bin/sh\nsleep 10' > /etc/rc.local
echo "$(which msfdb) start" >> /etc/rc.local

if [[ $(ip link show) =~ 00:0c:29 ]]; then
    debug "VMWare Specific, installing vmware-tools and adding mount-share-folders script."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq install open-vm-tools-desktop
    if ! [[ -f /usr/local/sbin/mount-shared-folders ]]; then
        cat <<EOF | sudo tee /usr/local/sbin/mount-shared-folders
#!/bin/sh
vmware-hgfsclient | while read folder; do
  vmwpath="/mnt/hgfs/\${folder}"
  echo "[i] Mounting \${folder}   (\${vmwpath})"
  sudo mkdir -p "\${vmwpath}"
  sudo umount -f "\${vmwpath}" 2>/dev/null
  sudo vmhgfs-fuse -o allow_other -o auto_unmount ".host:/\${folder}" "\${vmwpath}"
done
sleep 2s
EOF
        sudo chmod +x /usr/local/sbin/mount-shared-folders
    fi
    echo "/usr/local/sbin/mount-shared-folders" >> /etc/rc.local
    /usr/local/sbin/mount-shared-folders
fi

echo "exit 0" >> /etc/rc.local
chmod +x /etc/rc.local
cp ${scriptdir}/configs/rc-local.service /etc/systemd/system/rc-local.service
systemctl enable rc-local

debug "Update mlocate"
updatedb

rm -f ~/.firstrun

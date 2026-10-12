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
    echo -e "\e[94m$0 [-d] [-l] [-u USER] [-g] [-s USER] [-k URL] [-K URL] [--insecure] [-c] [-b] [-a] [-q]\e[0m"
    echo -e "\t-d Don't pull any container images."
    echo -e "\t-l Don't setup a user to log in automatically."
    echo -e "\t-u Set the automatic login user.  Defaults to kali (if present) or root."
    echo -e "\t-g Don't clone select repos from github to /opt."
    echo -e "\t-s USER Install SSH Keys for USER from github.com."
    echo -e "\t-k URL Pull a SSH private key from an HTTP(S) URL (basic auth optional:"
    echo -e "\t   https://user:password@host/key). Also pulls URL.pub if it exists."
    echo -e "\t   Implies sshd hardening. Prompts if user given without password."
    echo -e "\t   Falls back to the SSHKEYURL environment variable (use sudo -E)."
    echo -e "\t-K URL Pull the API keys file for ~/.bashrc.d the same way (env: APIKEY_URL)."
    echo -e "\t--insecure Don't verify TLS certs for -k/-K pulls."
    echo -e "\t-c Don't update config dotfiles (vim, terminator, etc)."
    echo -e "\t-b Skip pulling Exploit Database's Binary Exploits."
    echo -e "\t-a Install AI tooling (opencode, litellm) for root and the autologin user."
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
    if [[ $2 =~ exitnow ]]; then
        exit 1
    fi
    sleep 1
}

if [[ $EUID -ne 0 ]]; then
    warn "This script needs to be run as root." exitnow
fi

if ! grep -q '/usr/sbin' <<< $PATH; then
    debug "Changing PATH since it's missing /usr/sbin"
    export PATH='/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin'
fi

# Variables and settings
export DEBIAN_FRONTEND=noninteractive
aptpackages=(vim htop terminator git libssl-dev libffi-dev python3-dev python3-pip pipx python3-venv tcpdump sshpass xterm colordiff mingw-w64 plocate podman podman-docker)
githubclone=(m0nad/Diamorphine f0rb1dd3n/Reptile h3xduck/TripleCross akamai/Linux-Process-Injection)
# docker.io/library/python:2.7.18 included for legacy exploitdb scripts.
containerimages=(docker.io/kalilinux/kali-rolling docker.io/library/python:2.7.18 docker.io/library/python docker.io/library/nginx lscr.io/linuxserver/swag docker.io/library/ubuntu:latest)
verbose=1
unset skipcontainers skipautologin skipgithub sshuser skipdotfiles skipbinsploits installai sshkeyurl apikeyurl insecure
args=(); for a in "$@"; do [[ $a == --insecure ]] && insecure=1 || args+=("$a"); done; set -- "${args[@]}"
while getopts 'hdlgs:u:cbqak:K:' flag; do
    case "${flag}" in
        d) skipcontainers=1 ;;
        l) skipautologin=1 ;;
        g) skipgithub=1 ;;
        s) sshuser=${OPTARG} ;;
        k) sshkeyurl=${OPTARG} ;;
        K) apikeyurl=${OPTARG} ;;
        c) skipdotfiles=1 ;;
        b) skipbinsploits=1 ;;
        a) installai=1 ;;
        q) verbose=0 ;;
        u) autologinuser=${OPTARG} ;;
        h) usage ;;
        *) usage ;;
    esac
done
: "${sshkeyurl:=$SSHKEYURL}"
: "${apikeyurl:=$APIKEY_URL}"
# After getopts: nocasematch would make case patterns match -K as -k.
shopt -s nocasematch

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

# Allows dconf/xfconf writesto persist even if not in a GUI.
as_user_dbus () {
    if [[ $autologinuser == "root" ]]; then
        dbus-run-session -- "$@"
    else
        sudo -u $autologinuser dbus-run-session -- "$@"
    fi
}

# set xfce settings
xfconf_set () {
    # $1 channel, $2 property, $3 type, $4 value
    as_user_dbus xfconf-query -c "$1" -p "$2" -s "$4" 2>/dev/null || \
        as_user_dbus xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4"
}

pull_image () {
    if [[ $autologinuser == "root" ]]; then
        podman pull "$1"
    else
        if ! sudo -u $autologinuser XDG_RUNTIME_DIR=/run/user/"$(id -u $autologinuser)" podman pull "$1"; then
            warn "Rootless pull of $1 failed, pulling as root instead."
            podman pull "$1"
        fi
    fi
}

# Install bashrc.d snippets and hook the loader into .bashrc.
install_bashrc_d () {
    local home=$1
    local manifest="$home/.bashrc.d/.kali-setup-installed"
    mkdir -p "$home/.bashrc.d"
    # Remove snippets that have left the repo; user-added files stay.
    cat "$manifest" 2>/dev/null | while read -r name; do
        [[ $name && $name != */* && ! -e $scriptdir/configs/bashrc.d/$name ]] && rm -f "$home/.bashrc.d/$name"
    done
    cp --remove-destination "$scriptdir"/configs/bashrc.d/*.sh "$home/.bashrc.d/"
    (cd "$scriptdir/configs/bashrc.d" && printf '%s\n' *.sh) > "$manifest"
    if ! grep -q '\.bashrc\.d' "$home/.bashrc" 2>/dev/null; then
        cat >> "$home/.bashrc" <<'EOF'

# Load per-topic config from ~/.bashrc.d/ (sourced in name order)
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*.sh; do
        [ -r "$rc" ] && . "$rc"
    done
    unset rc
fi
EOF
    fi
    if [[ ! -e $home/.bashrc.d/15-api-keys.sh ]]; then
        install -m 600 /dev/null "$home/.bashrc.d/15-api-keys.sh"
        echo '# rc file for API keys and tokens.' > "$home/.bashrc.d/15-api-keys.sh"
    fi
}

# Run a command as the home's owner with HOME set.
as_home_owner () {
    local home=$1
    shift
    if [[ $home == /root ]]; then
        env HOME=/root "$@"
    else
        sudo -Hu $autologinuser "$@"
    fi
}

# Pull $1 (http(s)://[user[:pass]@]host/path) to $2 with mode ${3:-600}.
pull_url () {
    local url=$1 dest=$2 mode=${3:-600}
    local scheme=${url%%://*} rest=${url#*://} userinfo= user= pass=
    [[ $scheme == http || $scheme == https ]] || { echo "Only http(s) URLs supported: $url" >&2; return 1; }
    # logic for working with special characters. Not tested much since I use xkcd style.
    if [[ $rest == *@* ]]; then
        userinfo=${rest%@*}                 # last @, so @ survives in passwords
        rest=${rest##*@}
        user=${userinfo%%:*}                # first colon, so colons survive in passwords
        [[ $userinfo == *:* ]] && pass=${userinfo#*:}
    fi
    [[ $rest == */* ]] || { echo "URL needs host and path: $url" >&2; return 1; }
    local args=(-fsSL)
    [[ ${insecure:-} ]] && args+=(--insecure)
    if [[ $user ]]; then
        [[ $userinfo == *:* ]] || { read -rsp "Password for $user@${rest%%/*}: " pass; echo; }
        args+=(-u "$user:$pass")
    fi
    curl "${args[@]}" "$scheme://$rest" -o "$dest" || { rm -f "$dest"; return 1; }
    chmod "$mode" "$dest"
}

if [[ -f /root/.firstrun ]]; then
    debug "Looks like we rebooted after a kernel update... not running initial updates."
else
    debug "Disabling system beep."
    echo -e '#!/bin/sh\nsetterm blength 0' > /etc/profile.d/disable-beep.sh
    chmod 755 /etc/profile.d/disable-beep.sh
    debug "Creating ssh directories if they don't exist."
    if [[ ! -d /root/.ssh/ ]]; then
        mkdir -v /root/.ssh
        chmod 700 /root/.ssh
    fi
    if [[ $autologinuser != "root" ]] && [[ ! -d /home/$autologinuser/.ssh ]]; then
        mkdir -v /home/$autologinuser/.ssh
        chmod 700 /home/$autologinuser/.ssh
        chown $autologinuser:$autologinuser /home/$autologinuser/.ssh
    fi
    if [[ $sshkeyurl ]]; then
        debug "Pulling $sshkeyurl and saving to root and ${autologinuser}."
        FILENAME=$(basename "${sshkeyurl#*://}")
        pull_url "$sshkeyurl" "/root/.ssh/$FILENAME" || warn "Error pulling SSH private key." exitnow
        pull_url "${sshkeyurl}.pub" "/root/.ssh/$FILENAME.pub" 644 2>/dev/null
        if [[ $autologinuser != "root" ]]; then
            cp "/root/.ssh/$FILENAME" "/home/$autologinuser/.ssh/$FILENAME"
            [[ -f /root/.ssh/$FILENAME.pub ]] && cp "/root/.ssh/$FILENAME.pub" "/home/$autologinuser/.ssh/$FILENAME.pub"
            chown $autologinuser:$autologinuser "/home/$autologinuser/.ssh/$FILENAME"*
        fi
    fi
    if [[ $autologinuser != "root" ]]; then
        debug "Setting up passwordless sudo for the sudo group."
        sed -i 's/.*%sudo.*/%sudo         ALL = (ALL) NOPASSWD: ALL/g' /etc/sudoers
    fi

    debug "Switching from zsh to bash because zsh is annoying."
    for user in root $autologinuser; do
        if [[ $(getent passwd $user | cut -d: -f7) != "/bin/bash" ]]; then
            chsh -s /bin/bash $user
        fi
    done

    if ! [[ $skipautologin ]]; then
        debug "Setting up $autologinuser to automatically log in (lightdm)."
        sed -i "s,^\[Seat:\*\],[Seat:*]\nautologin-guest=false\nautologin-user=$autologinuser\nautologin-user-timeout=0,g" /etc/lightdm/lightdm.conf
        if [[ $autologinuser != "root" ]]; then
            debug "Don't have chromium ask for keyring."
            sed -i 's#/usr/bin/chromium %U#/usr/bin/chromium --password-store=basic %U#g' $(grep -irl 'Name=Chromium Web Browser' /home/$autologinuser/.config/xfce4/ 2>/dev/null) /usr/share/applications/chromium.desktop 2>/dev/null
        fi
    fi
    debug "Turning off power management and the screensaver."
    xfconf_set xfce4-power-manager /xfce4-power-manager/blank-on-ac int 0
    xfconf_set xfce4-power-manager /xfce4-power-manager/dpms-on-ac-sleep uint 0
    xfconf_set xfce4-power-manager /xfce4-power-manager/dpms-on-ac-off uint 0
    xfconf_set xfce4-power-manager /xfce4-power-manager/dpms-enabled bool true
    xfconf_set xfce4-screensaver /saver/enabled bool false
    xfconf_set xfce4-screensaver /saver/idle-activation/enabled bool false
    xfconf_set xfce4-screensaver /lock/enabled bool false

    debug "Removing built in SSH keys"
    rm -f /etc/ssh/ssh_host_*
    dpkg-reconfigure openssh-server > /dev/null

    debug "Updating everything.  Stopping packagekitd for some releases of Kali."
    systemctl stop packagekit
    systemctl disable packagekit
    # Sometimes a child process from the auto update keeps running.
    if [[ -f /var/lib/apt/lists/lock ]]; then
        sleep 1
        fuser -s -k /var/lib/apt/lists/lock
        sleep 1
    fi
    # Piping apt output to null since the -q flag doesn't get passed to the underlying dpkg for some reason. 
    # STDERR should still show.
    debug "Updating repos."
    apt-get -yq update >/dev/null || warn "Error in apt-get update" exitnow
    debug "Updating installed packages.  This will take a while."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq dist-upgrade >/dev/null || warn "Error in updating installed packages." exitnow
    debug "Installing packages, this will take a while."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq install "${aptpackages[@]}" >/dev/null || warn "Error when trying to install new packages" exitnow
    debug "Autoremoving things we don't need anymore."
    apt-get -yq autoremove >/dev/null || warn "Error in autoremove." exitnow
    debug "Settings cap_net_bind_service for some binaries (Python, Ruby, netcat, etc) to allow low port-asignment without needing root."
    find /bin /sbin /usr/sbin /usr/bin -regextype egrep -type f  -iregex '.*(python|ruby|/ncat|nc.traditional|nmap).*' -exec file {} \; | awk -F':' '/ELF/ { print $1 }' | xargs -I '{}' setcap cap_net_raw,cap_net_bind_service=+eip {}
    touch /root/.firstrun
fi

debug "Checking to see if we need to reboot after the update due to a new kernel."
running=$(uname -r)
ondisk=$(dpkg --list | awk '/linux-image-[0-9]+/ {print $2}' | sort -V | tail -1)
if [[ $ondisk == *${running}* ]] || ! [[ -f /var/run/reboot-required ]]; then
    debug "Looks good ... continuing."
else
    warn "Looks like we need to reboot due to an update."
    read -p "Reboot? [Y/n]"
    if [[ ${REPLY,,} =~ ^n ]]; then
        warn "Ok, if you say so ..."
    else
        reboot
    fi
fi

if [[ $sshuser || $sshkeyurl ]]; then
    if [[ $sshuser ]]; then
        debug "Adding ${sshuser}'s github keys."
        curl -s https://github.com/${sshuser}.keys > /root/.ssh/authorized_keys || exit 1
        if [[ $autologinuser != "root" ]]; then
            cp /root/.ssh/authorized_keys /home/$autologinuser/.ssh/
            chmod 600 /root/.ssh/authorized_keys /home/$autologinuser/.ssh/authorized_keys
            chown $autologinuser:$autologinuser /home/$autologinuser/.ssh /home/$autologinuser/.ssh/authorized_keys
        fi
    fi
    debug "Hardening and enabling sshd."
    sed -i 's,.*PermitRootLogin.*,PermitRootLogin prohibit-password,g ; s,.*KbdInteractiveAuthentication.*,KbdInteractiveAuthentication no,g ; s,.*PasswordAuthentication.*,PasswordAuthentication no,g' /etc/ssh/sshd_config
    systemctl enable ssh
    systemctl start ssh
fi

if [[ $skipgithub ]]; then
    debug "Not pulling select repos from github."
else
    debug "Set up git repos in /opt"
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

if [[ $skipcontainers ]]; then
    debug "Skipping containers"
else
    if [[ $autologinuser != "root" ]]; then
        loginctl enable-linger $autologinuser
    fi
    for image in "${containerimages[@]}"; do
        debug "Pulling $image"
        pull_image $image
    done
fi

if [[ $skipbinsploits ]]; then
    debug "Skipping pulling binary exploits."
else
    git clone https://gitlab.com/exploit-database/exploitdb-bin-sploits /opt/bin-sploits/
fi

if [[ $apikeyurl && $skipdotfiles ]]; then
    warn "API keys URL given but dotfiles are being skipped (-c)."
fi

if [[ $skipdotfiles ]]; then
    debug "Skipping setting up dotfiles."
else
    debug "Updating dotfiles."
    if [[ $apikeyurl ]]; then
        apikeytmp=$(mktemp)
        pull_url "$apikeyurl" "$apikeytmp" || warn "Error pulling API keys file." exitnow
    fi
    targethomes=(/root)
    if [[ $autologinuser != "root" ]]; then
        targethomes+=(/home/$autologinuser)
    fi
    for home in "${targethomes[@]}"; do
        install_bashrc_d "$home"
        [[ $apikeyurl ]] && install -m 600 "$apikeytmp" "$home/.bashrc.d/15-api-keys.sh"
        mkdir -p "$home/.config/terminator"
        cp --remove-destination $scriptdir/configs/terminator_config "$home/.config/terminator/config"
        cp --remove-destination $scriptdir/configs/vimrc "$home/.vimrc"
        cp --remove-destination $scriptdir/configs/tmux.conf "$home/.tmux.conf"
        # Back up a differing pre-existing ssh config.
        install -d -m 700 "$home/.ssh"
        if [[ -f $home/.ssh/config && ! -L $home/.ssh/config && ! -e $home/.ssh/config.pre-kali-setup ]] \
            && ! cmp -s $scriptdir/configs/ssh_config "$home/.ssh/config"; then
            mv -v "$home/.ssh/config" "$home/.ssh/config.pre-kali-setup"
        fi
        rm -f "$home/.ssh/config"
        install -m 600 $scriptdir/configs/ssh_config "$home/.ssh/config"
        if [[ $home != /root ]]; then
            chown -R $autologinuser:$autologinuser "$home/.bashrc.d" "$home/.config" "$home/.ssh" "$home/.vimrc" "$home/.tmux.conf"
        fi
    done
    [[ $apikeyurl ]] && rm -f "$apikeytmp"
    debug "Applying git hygiene settings."
    for home in "${targethomes[@]}"; do
        as_home_owner "$home" git config --global init.defaultBranch main
        as_home_owner "$home" git config --global pull.ff only
        as_home_owner "$home" git config --global push.autoSetupRemote true
        as_home_owner "$home" git config --global fetch.prune true
        as_home_owner "$home" git config --global rebase.autoStash true
        as_home_owner "$home" git config --global merge.conflictStyle zdiff3
        as_home_owner "$home" git config --global rerere.enabled true
    done
fi

if [[ $installai ]]; then
    debug "Installing AI tooling (opencode and litellm)."
    aitargets=(/root)
    if [[ $autologinuser != "root" ]]; then
        aitargets+=(/home/$autologinuser)
    fi
    for home in "${aitargets[@]}"; do
        mkdir -p "$home/.local/bin" "$home/.opencode"
        # v2 installer hardcodes ~/.opencode/bin; symlink into ~/.local/bin.
        if [[ -d $home/.opencode/bin && ! -L $home/.opencode/bin ]]; then
            debug "$home/.opencode/bin already exists as a real directory, not symlinking."
        else
            ln -sfn "$home/.local/bin" "$home/.opencode/bin"
        fi
        if [[ $home != /root ]]; then
            chown -R $autologinuser:$autologinuser "$home/.local" "$home/.opencode"
        fi
        tries=0
        until as_home_owner "$home" bash -c 'curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path'; do
            (( ++tries >= 3 )) && { warn "opencode install failed for $home"; break; }
            sleep 5
        done
        as_home_owner "$home" bash -c 'pipx list --short 2>/dev/null | grep -q ^litellm || pipx install litellm' || warn "litellm install failed for $home"
        # Fall back to .bashrc for PATH when dotfiles are skipped.
        if [[ $skipdotfiles ]] && ! grep -q '\.local/bin' "$home/.bashrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$home/.bashrc"
        fi
    done
fi

debug "MSFDB init"
msfdb init
msfdb start

debug "Installing helper scripts to /usr/local/sbin."
cp --remove-destination $scriptdir/configs/sbin/update-system.sh $scriptdir/configs/sbin/vpn-strict.sh /usr/local/sbin/

if [[ $(ip link show) =~ 00:0c:29 ]] || ps -ef | grep -q '[v]mtoolsd'; then
    debug "VMWare Specific, installing vmware-tools and adding vmware helper scripts."
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -yq install open-vm-tools-desktop
    cp --remove-destination $scriptdir/configs/sbin/mount-shared-folders $scriptdir/configs/sbin/restart-vm-tools /usr/local/sbin/
    /usr/local/sbin/mount-shared-folders
fi

debug "Installing post-boot systemd unit (msfdb + shared folders)."
cp $scriptdir/configs/msfdb-shared-folders.service /etc/systemd/system/msfdb-shared-folders.service
systemctl daemon-reload
systemctl enable msfdb-shared-folders

debug "Running updatedb"
updatedb

rm -f /root/.firstrun

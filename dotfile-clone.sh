#!/bin/bash
if ! [[ $2 ]]; then
    exit 1
fi
autologinuser=$1
sshuser=$2
pushd /home/$autologinuser/
# Code 0 means keys are added, 1 means working but no keys, 2 is no agent.
agentstatus=$(ssh-add -l >/dev/null 2>&1 ; echo $?)
if [[ $agentstatus -eq "2" ]]; then
    eval $(ssh-agent)
fi
for file in $(grep -irl 'PRIVATE KEY' .ssh/); do
    ssh-add $file
done
git clone git@github.com:${sshuser}/dotfiles.git
if [[ -f ./dotfiles/setup.sh ]]; then
    pushd dotfiles
    ./setup.sh
    popd
fi
popd

# Add SSH keys for interactive shells.  Start ssh-agent if GUI didn't.
if [[ $- == *i* ]] && command -v ssh-agent >/dev/null 2>&1; then
    # Code 0 means keys are added, 1 means working but no keys, 2 is no agent.
    agentstatus=$(ssh-add -l >/dev/null 2>&1 ; echo $?)
    if [[ -f /dev/shm/.${USER}.ssh-agent ]]; then
        source /dev/shm/.${USER}.ssh-agent
    elif [[ $agentstatus -eq "2" ]]; then
        ssh-agent | head -2 > /dev/shm/.${USER}.ssh-agent
        chmod 600 /dev/shm/.${USER}.ssh-agent
        source /dev/shm/.${USER}.ssh-agent
    fi
    # Only works if sshkeys are generated with -C '' so the file path is shown.
    for file in $(grep -irl 'PRIVATE KEY' $HOME/.ssh/); do 
        if ! ssh-add -l | grep -q $file || ! ssh-add -l | grep -q "$(ssh-keygen -lf ${file}.pub | awk '{print $2}')" ; then
            ssh-add $file
        fi 
    done
    unset agentstatus file
fi

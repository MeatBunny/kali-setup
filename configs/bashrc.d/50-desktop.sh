# systemd user session, desktop and container runtime

# systemd user
if [[ -d /run/user/$(id -u) ]]; then
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
fi

# Turn off beep
if command -v xset >/dev/null 2>&1 && [[ $DISPLAY ]]; then
    xset b off
fi

# Use Podman socket for Docker-API tools (docker-compose, testcontainers, etc.)
if [[ -S $XDG_RUNTIME_DIR/podman/podman.sock ]]; then
    export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
fi

# Docker
if command -v docker >/dev/null 2>&1; then
    alias docker="sudo docker"
    alias dockerclean="docker ps -a | grep Exited | grep -oP '^[a-z0-9]{12}' | xargs docker rm"
fi

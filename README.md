# kali-setup

Setup script to add extra tools and sensible configs to a Kali install (XFCE only, VMWare focused) from various git repositories.

1. Sets up autologin for specified users (default kali).
1. Pulls podman container images and clones Github repositories.
1. Sets up dotfiles: modular `~/.bashrc.d` snippets (with a private, mode-600 `15-api-keys.sh` placeholder for secrets), plus vim, tmux, terminator, and ssh configs.
1. Installs helper scripts to `/usr/local/sbin`: `update-system.sh` (apt/dnf updater), `vpn-strict.sh` (OpenVPN killswitch), and VMWare helpers.
1. Optionally pulls a SSH private key (plus its `.pub` if present) and an API keys file for `~/.bashrc.d` from HTTP(S) URLs with optional basic auth (`-k`/`-K`, `--insecure`; env: `SSHKEYURL`/`APIKEY_URL`).
1. Optionally installs AI tooling (`opencode`, `litellm`) with `-a`.
1. Applies git hygiene defaults (ff-only pulls, default branch `main`, rerere, etc).
1. Allows some binaries (Python, Ruby, netcat, etc) to open privileged ports to cut down on the number of times sudo is needed.

Run `setup.sh -h` for the full flag list.

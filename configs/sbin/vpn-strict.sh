#!/bin/bash

# 0 = full lock-down (no local network); 1 = allow local network (DNS still dropped).
ALLOW_LOCAL=1

if ! [[ $1 ]]; then
    echo "Usage:  $0 /path/to/config.ovpn" >&2
    exit 1
fi

config="$1"

if ! [[ -f $config ]]; then
    echo "Error: Config file '$config' does not exist." >&2
    exit 1
fi

echo "Parsing config for remote endpoints..."
# Try to extract 'remote IP PORT' or fall back to 'remote IP' and separate 'port'
remote_line=$(grep -E '^[ \t]*remote ' "$config" | head -n 1)
read -r _ remote_ip remote_port <<< "$remote_line"
proto=$(grep -E '^[ \t]*proto ' "$config" | head -n 1 | awk '{print $2}')

if [[ -z "$remote_port" ]]; then
    remote_port=$(grep -E '^[ \t]*port ' "$config" | head -n 1 | awk '{print $2}')
    [[ -z "$remote_port" ]] && remote_port=1194
fi

if [[ -z "$proto" ]]; then
    proto="udp"
fi

if [[ -z "$remote_ip" ]]; then
    echo "Error: Could not find 'remote' IP in $config." >&2
    exit 1
fi

echo "VPN Server: $remote_ip : $remote_port ($proto)"

cleanup() {
    echo -e "\nRestoring IPTables and normal networking..."
    # Remove the jump from OUTPUT
    sudo iptables -D OUTPUT -j VPN_KILLSWITCH 2>/dev/null
    # Flush and delete the custom chain
    sudo iptables -F VPN_KILLSWITCH 2>/dev/null
    sudo iptables -X VPN_KILLSWITCH 2>/dev/null
    echo "Network restored."
}

# Always restore the firewall on exit.
trap cleanup EXIT SIGINT SIGTERM

echo "Locking down network with strict killswitch..."

# Prevent duplicate chains by attempting a silent cleanup first
cleanup &> /dev/null

# Create new custom chain
sudo iptables -N VPN_KILLSWITCH

# Rule 1: Always allow traffic over the VPN tunnel itself
sudo iptables -A VPN_KILLSWITCH -o tun+ -j ACCEPT

# Rule 2: Allow connection to the specific VPN server
sudo iptables -A VPN_KILLSWITCH -d "$remote_ip" -p "$proto" --dport "$remote_port" -j ACCEPT

# Rule 3: Local network access
if [[ "$ALLOW_LOCAL" == "1" ]]; then
    echo "Allowing local network access (DNS blocked)..."
    # Get local subnets, excluding loopback
    local_nets=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')
    for net in $local_nets; do
        # Prevent DNS leaks over local network
        sudo iptables -A VPN_KILLSWITCH -d "$net" -p udp --dport 53 -j DROP
        sudo iptables -A VPN_KILLSWITCH -d "$net" -p tcp --dport 53 -j DROP
        # Allow other local traffic
        sudo iptables -A VPN_KILLSWITCH -d "$net" -j ACCEPT
    done
fi

# Rule 4: Drop EVERYTHING else
sudo iptables -A VPN_KILLSWITCH -j DROP

# Activate the killswitch by inserting it at the top of OUTPUT
sudo iptables -I OUTPUT -j VPN_KILLSWITCH

echo "Firewall locked. Launching OpenVPN..."
sudo openvpn --config "$config"

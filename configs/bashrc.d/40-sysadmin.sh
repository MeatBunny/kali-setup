# Root/sudo, networking, firewall, package and service aliases

# become root #
alias root='sudo -i'

# reboot / halt / poweroff
alias reboot='sudo /sbin/reboot'
alias poweroff='sudo /sbin/poweroff'
alias halt='sudo /sbin/halt'
alias shutdown='sudo /sbin/shutdown'

# Services
if command -v systemctl >/dev/null 2>&1; then
    alias systemctl='sudo systemctl'
fi

alias updatedb='sudo updatedb'

# Get open ports
if command -v netstat >/dev/null 2>&1; then
    alias ports='netstat -tulanp'
fi

## shortcut  for iptables and pass it via sudo#
if [[ -x /sbin/iptables ]]; then
    alias ipt='sudo /sbin/iptables'
    alias iptables='sudo /sbin/iptables'

    # display all rules #
    alias iptlist='sudo /sbin/iptables -L -n -v --line-numbers'
    alias iptlistin='sudo /sbin/iptables -L INPUT -n -v --line-numbers'
    alias iptlistout='sudo /sbin/iptables -L OUTPUT -n -v --line-numbers'
    alias iptlistfw='sudo /sbin/iptables -L FORWARD -n -v --line-numbers'
fi

# distro specific  - Debian / Ubuntu and friends #
if command -v apt-get >/dev/null 2>&1; then
    # install with apt-get
    alias apt="sudo apt"
    alias apt-get="sudo apt-get"
    alias updatey="sudo apt-get --yes"

    # update on one command
    alias upgrade='sudo apt-get update && sudo apt-get upgrade'
fi

# pcap
if command -v wireshark >/dev/null 2>&1; then
    alias popshark='sudo wireshark >/dev/null 2>&1 &'
fi

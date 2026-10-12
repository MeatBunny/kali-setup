#!/bin/bash

EXTRA_APT_OPTS=""
EXTRA_DNF_OPTS=""

if [[ $1 == --force-unsafe ]]; then
    EXTRA_APT_OPTS="--allow-downgrades --allow-remove-essential --allow-change-held-packages"
    EXTRA_DNF_OPTS="--allowerasing"
elif [[ $1 ]]; then
    echo "Unknown parameter passed: $1" >&2; exit 1
fi

if command -v apt-get &> /dev/null; then
    echo "Detected Debian/Ubuntu-based system. Running apt..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get -yq update || exit 1
    apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef $EXTRA_APT_OPTS -yq dist-upgrade || exit 1
    apt-get -yq autoremove || exit 1

elif command -v dnf &> /dev/null; then
    echo "Detected Fedora/Nobara-based system. Running dnf..."
    dnf upgrade -y $EXTRA_DNF_OPTS || exit 1
    dnf autoremove -y || exit 1

else
    echo "Error: Neither apt-get nor dnf found. Unsupported system."
    exit 1
fi

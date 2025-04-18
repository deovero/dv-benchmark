#!/usr/bin/env bash
set +o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 package1 [package2 ...]" >&2
    exit 1
fi

# Store all arguments in an array
PACKAGES=("$@")

# Print packages to be installed
echo "Installing packages:"
printf -- '- %s\n' "${PACKAGES[@]}"
echo

# Prepare working directory
WORKDIR="${SCRIPT_DIR}/tmp"
mkdir -p "${WORKDIR}" || {
    echo "Error: Failed to create working directory ${WORKDIR}" >&2
    exit 1
}
cd "${WORKDIR}" || {
    echo "Error: Failed to change to working directory ${WORKDIR}" >&2
    exit 1
}

if [[ 0 == "$UID" ]]; then
    echo "You are root, using apt-get."
    apt-get -y install "${PACKAGES[@]}" || {
        echo "Error: apt-get installation failed" >&2
        exit 1
    }
else
    echo "You are not root, using user_deb.sh."
    "${SCRIPT_DIR}/user_deb.sh" "${PACKAGES[@]}" || {
        echo "Error: user_deb.sh installation failed" >&2
        exit 1
    }
fi

date >> "${WORKDIR}/installed.date" || {
    echo "Warning: Failed to update installed.date" >&2
}

echo "Installation done."
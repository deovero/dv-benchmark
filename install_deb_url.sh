#!/usr/bin/env bash
set +o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 https://example.com/package.deb" >&2
    exit 1
fi

# Store all arguments in an array
URL="${1}"

# Print packages to be installed
echo "Installing package:"
printf -- '- %s\n' "${URL}"
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
    echo "You are root, using dpkg."
    wget -q "${URL}" -O tmp.deb || {
        echo "Error: Failed to download package" >&2
        exit 1
    }
    apt-get -y install ./tmp.deb || {
        echo "Error: apt-get installation failed" >&2
        exit 1
    }
else
    echo "You are not root, using user_deb.sh."
    wget -q "${URL}" -O tmp.deb || {
        echo "Error: Failed to download package" >&2
        exit 1
    }
    "${SCRIPT_DIR}/user_deb.sh" "$(readlink -f ./tmp.deb)" || {
        echo "Error: user_deb.sh installation failed" >&2
        exit 1
    }
fi

rm -f tmp.deb

echo "Installation done."

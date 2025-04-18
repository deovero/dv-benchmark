#!/usr/bin/env bash
set +o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 package1|url1 [package2 ...]" >&2
    exit 1
fi

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

# Function to install a package or URL
install_item() {
    local item="$1"

    if [[ "${item}" == https://* ]] || [[ "${item}" == http://* ]]; then
        echo "Installing from URL: ${item}"
        if [[ 0 == "$UID" ]]; then
            echo "You are root, using dpkg."
            wget -q "${item}" -O tmp.deb || {
                echo "Error: Failed to download package" >&2
                return 1
            }
            apt-get -y install ./tmp.deb || {
                echo "Error: apt-get installation failed" >&2
                rm -f tmp.deb
                return 1
            }
            rm -f tmp.deb
        else
            echo "You are not root, using user_deb.sh."
            "${SCRIPT_DIR}/user_deb.sh" "${item}" || {
                echo "Error: user_deb.sh installation failed" >&2
                return 1
            }
        fi
    else
        echo "Installing package: ${item}"
        if [[ 0 == "$UID" ]]; then
            echo "You are root, using apt-get."
            apt-get -y install "${item}" || {
                echo "Error: apt-get installation failed" >&2
                return 1
            }
        else
            echo "You are not root, using user_deb.sh."
            "${SCRIPT_DIR}/user_deb.sh" "${item}" || {
                echo "Error: user_deb.sh installation failed" >&2
                return 1
            }
        fi
    fi
}

# Print items to be installed
echo "Installing items:"
printf -- '- %s\n' "$@"
echo

# Process each item
for ITEM in "$@"; do
    if ! install_item "${ITEM}"; then
        echo "Error: Failed to install '${ITEM}'" >&2
        exit 1
    fi
done

echo "Installation done."
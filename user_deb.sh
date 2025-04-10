#!/bin/bash
#
# Script to download and extract Debian packages without root privileges
#

# Set shell options
set +o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prepare working directory
WORKDIR="${SCRIPT_DIR}/tmp"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

# Get distribution id, 'Debian' or 'Ubuntu'
DISTRIB_ID="$( lsb_release --id --short 2>/dev/null )"

# Check if a package name is provided as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <package_name> [package_name...]" >&2
    exit 1
fi

install_package() {
    local PACKAGE="$1"
    
    # Check if already installed globally
    if dpkg -s "$PACKAGE" >/dev/null 2>&1; then
        echo "Package '$PACKAGE' is already installed globally. Skipping."
        return 0
    fi

    # Check if already installed locally
    touch installed.lst
    if grep -q "^${PACKAGE}$" installed.lst; then
        echo "Package '$PACKAGE' is already installed locally. Skipping."
        return 0
    fi

    # Extract the filename from the package information
    local filename
    filename=$(apt-cache show "$PACKAGE" | grep "^Filename:" | head -n1 | awk '{print $2}')

    # Check if filename was found
    if [ -z "$filename" ]; then
        echo "Error: Filename not found for package '$PACKAGE'" >&2
        return 1
    fi

    # Construct the download URL
    BASEURL=$(apt-cache policy "$PACKAGE" | grep 'http' | head -n1 | awk '{print $2}')
    local download_url
    download_url="${BASEURL}/${filename}"

    echo "Installing '${PACKAGE}' from '${download_url}'..."
    
    # Download and extract DEB
    if ! wget -q "$download_url" -O tmp.deb; then
        echo "Error: Failed to download package '$PACKAGE'" >&2
        return 1
    fi

    rm -rf unpack
    if ! dpkg -x tmp.deb unpack; then
        echo "Error: Failed to extract package '$PACKAGE'" >&2
        rm -f tmp.deb
        return 1
    fi

    cp -a unpack/* .
    rm -rf unpack tmp.deb

    echo "${PACKAGE}" >> installed.lst
    echo "Successfully installed '${PACKAGE}'"

    # Install dependencies
    while read -r DEPENDS; do
        if [[ -n "$DEPENDS" ]]; then
            install_package "${DEPENDS}"
        fi
    done < <(apt-get -s install "$PACKAGE" | grep -P '^Inst' | grep -Fv "Inst ${PACKAGE} " | awk '{ print $2 }' )
}

# Process each package
for PACKAGE in "$@"; do
    if ! install_package "$PACKAGE"; then
        echo "Error: Failed to install package '$PACKAGE'" >&2
        exit 1
    fi
done

exit 0
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
    echo "Usage: $0 <package_name|/path/to/package.deb> [package_name...]" >&2
    exit 1
fi

check_installed() {
    local package_name="$1"

    # Check if already installed globally
    if dpkg -s "${package_name}" >/dev/null 2>&1; then
        return 0
    fi

    # Check if already installed locally
    touch installed.lst
    if grep -q "^${package_name}$" installed.lst; then
        return 0
    fi

    return 1
}

install_package() {
    local package_file="tmp.deb"
    local package_name
    local package_url
    local do_download=true
    local dependencies

    # Handle full path to .deb file
    if [[ "${1}" == https://* ]] || [[ "${1}" == http://* ]]; then
        package_url="${1}"
    elif [[ "${1}" == *.deb ]]; then
        package_file="${1}"
        do_download=false
        if [[ ! -f "${package_file}" ]]; then
            echo "Error: File '${package_file}' not found" >&2
            return 1
        fi
        package_name=$(dpkg-deb -f "${package_file}" Package)
        echo "Installing '${package_name}' from '${package_file}'..."
    else
        package_name="${1}"
    fi

    if [[ -n "${package_name+x}" ]] && check_installed "${package_name}"; then
        return 0
    fi

    if [[ "${do_download}" == true ]]; then
        if [[ -z "${package_url+x}" ]]; then
            # Extract the filename from the package information
            local filename
            filename=$(apt-cache show "${package_name}" | grep "^Filename:" | head -n1 | awk '{print $2}')

            # Check if filename was found
            if [ -z "$filename" ]; then
                echo "Error: Filename not found for package '$PACKAGE'" >&2
                return 1
            fi

            # Construct the download URL
            BASEURL=$(apt-cache policy "${package_name}" | grep 'http' | head -n1 | awk '{print $2}')
            package_url="${BASEURL}/${filename}"
        fi

        # Download DEB
        echo "Downloading '${package_url}'..."
        if ! wget -q "${package_url}" -O "${package_file}"; then
            echo "Error: Failed to download package '${package_name}' from URL '${package_url}'" >&2
            return 1
        fi
        if [[ -z "${package_name+x}" ]]; then
            package_name=$(dpkg-deb -f "${package_file}" Package)
        fi
    fi

    if check_installed "${package_name}"; then
        return 0
    fi

    # Extract DEB
    rm -rf unpack
    if ! dpkg -x "${package_file}" unpack; then
        echo "Error: Failed to extract package '$PACKAGE'" >&2
        if [[ "${do_download}" == true ]]; then
            rm -f "${package_file}"
        fi
        return 1
    fi

    cp -a unpack/* .
    rm -rf unpack

    dependencies="$(
      apt-get -s install "$( readlink -f "${package_file}" )" | grep -P '^Inst' | grep -Fv "Inst ${package_name} " | awk '{ print $2 }'
    )"

    if [[ "${do_download}" == true ]]; then
        rm -f "${package_file}"
    fi

    echo "${package_name}" >> installed.lst
    echo "Successfully installed '${package_name}'"

    # Install dependencies
    while read -r DEPENDS; do
        if [[ -n "$DEPENDS" ]]; then
            install_package "${DEPENDS}"
        fi
    done <<< "${dependencies}"
}

# Process each package
for PACKAGE in "$@"; do
    if ! install_package "${PACKAGE}"; then
        echo "Error: Failed to install package '${PACKAGE}'" >&2
        exit 1
    fi
done

exit 0
#!/bin/bash
set +o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${SCRIPT_DIR}/tmp"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

# Script to get the download URL of a Debian package

source /etc/lsb-release

# Check if a package name is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <package_name>"
  exit 1
fi

for PACKAGE in "$@"; do

if dpkg -s "$PACKAGE" >/dev/null 2>&1; then
  echo "Package '$PACKAGE' is already installed globally. Skipping."
  exit 0
fi

touch installed.lst
if grep -q "${PACKAGE}" installed.lst; then
  echo "Package '$PACKAGE' is already installed locally. Skipping."
  exit 0
fi

while read -u 3 DEPENDS; do
  "${SCRIPT_DIR}/user_deb.sh" "${DEPENDS}"
done 3< <( apt-get -s install "$PACKAGE" | grep -P '^Inst' | awk '{ print $2 }' | grep -v "^${PACKAGE}\$" )


  # Extract the filename from the package information
  filename=$( apt-cache show "$PACKAGE" | grep "^Filename:" | head -n1 | awk '{print $2}')

  # Check if filename was found
  if [ -z "$filename" ]; then
    echo "Filename not found in package information."
    exit 1
  fi

  # Construct the download URL
  if [[ "Ubuntu" == "${DISTRIB_ID}" ]]; then
    download_url="http://archive.ubuntu.com/ubuntu/$filename"
  elif [[ "Ubuntu" == "${DISTRIB_ID}" ]]; then
    download_url="http://ftp.debian.org/debian/$filename"
  else 
    echo "Unkown distribution ${DISTRIB_ID}"
    exit 1
  fi

  echo "Installing '${PACKAGE}' from '${download_url}'..."
  
  # Download DEB
  wget -q "$download_url" -O tmp.deb

  # Unpack DEB
  rm -rf unpack
  dpkg -x tmp.deb unpack
  cp -a unpack/* .
  rm -rf unpack
  rm -f tmp.deb

echo "${PACKAGE}" >> installed.lst

done
exit 0
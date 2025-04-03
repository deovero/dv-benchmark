#!/usr/bin/env bash
set +o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Required packages
PACKAGES=( fio sysbench jq util-linux gawk )

if [[ 0 == "$UID" ]]; then
  echo "You are root, using apt-get."
  apt-get -y install "${PACKAGES[@]}"
else
  echo "You are not root, using user_deb.sh."
  "${SCRIPT_DIR}/user_deb.sh" "${PACKAGES[@]}"
fi

echo "Installation done."
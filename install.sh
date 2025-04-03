#!/usr/bin/env bash
set +o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Required packages
PACKAGES=( fio sysbench jq util-linux gawk )

# Prepare working directory
WORKDIR="${SCRIPT_DIR}/tmp"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

if [[ 0 == "$UID" ]]; then
  echo "You are root, using apt-get."
  apt-get -y install "${PACKAGES[@]}"
else
  echo "You are not root, using user_deb.sh."
  "${SCRIPT_DIR}/user_deb.sh" "${PACKAGES[@]}"
fi

date >> "${WORKDIR}/installed.date"
echo "Installation done."
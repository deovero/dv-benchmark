#!/usr/bin/env bash
set -o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'

if [[ 0 == "$UID" ]]; then
  # we are root
  apt-get -y install iozone3 fio sysbench jq
else
  echo "You are not root."
fi

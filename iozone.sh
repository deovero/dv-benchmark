#!/usr/bin/env bash
#
# Script to test disk IO performance using 'iozone'
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

echo "==== Installation ====="
"${SCRIPT_DIR}/install.sh" iozone3 util-linux grep gawk bc

export LD_LIBRARY_PATH="${WORKDIR}/usr/lib/x86_64-linux-gnu:${WORKDIR}/usr/lib/x86_64-linux-gnu/ceph:${WORKDIR}/lib/x86_64-linux-gnu"
export PATH="${WORKDIR}/usr/bin:${WORKDIR}/usr/local/bin:/usr/local/bin:/usr/bin:/bin"

# --- Configuration ---
# Set test file size
FILE_SIZE="${FILE_SIZE:-20G}"
# Set block size in Kbytes (4k is common for random IO)
BLOCK_SIZE="${BLOCK_SIZE:-4}"
# Set number of threads
THREADS="${THREADS:-4}"
# -------------------

# List block devices
echo
echo "==== Block Devices ===="
lsblk -o NAME,FSTYPE,MOUNTPOINT,SIZE,MODEL
echo

# Print test parameters
echo
echo "==== Test Parameters ===="
echo "- Size: ${FILE_SIZE}"
echo "- Block Size: ${BLOCK_SIZE}"
echo "- Threads: ${THREADS}"

# Check available space
required_bytes=$(numfmt --from=iec "$FILE_SIZE")
available_bytes=$(df -B1 --output=avail "${WORKDIR}" | tail -n1)
if [ "$required_bytes" -gt "$available_bytes" ]; then
    echo
    echo "Error: Not enough space available in ${WORKDIR}"
    echo "Required: $(numfmt --to=iec "$required_bytes")"
    echo "Available: $(numfmt --to=iec "$available_bytes")"
    exit 1
fi

# Function to run FIO test
run_iozone_test() {
    echo
    IOZONE_RESULT=$(
      iozone \
        -i0 \
        -i2 \
        -I \
        -e \
        -t "${THREADS}" \
        -s "${FILE_SIZE}" \
        -r "${BLOCK_SIZE}" \
        | tee /dev/tty
    )
    regex='Children see throughput for\s*[0-9]+\s+initial writers\s*=\s*([0-9]+\.?[0-9]*)\s*kB\/sec'
    RESULT=$(echo -e "${IOZONE_RESULT}" | grep -oP "${regex}" | tail -n1 | sed -nE "s/${regex}/\1/p")
    printf "\033[0;33mSequential Write:  %s MiB/sec\033[0m\n" "$(echo "${RESULT}/1024" | bc -l)"
    regex='Children see throughput for\s*[0-9]+\s+random readers\s*=\s*([0-9]+\.?[0-9]*)\s*kB\/sec'
    RESULT=$(echo -e "${IOZONE_RESULT}" | grep -oP "${regex}" | tail -n1 | sed -nE "s/${regex}/\1/p")
    printf "\033[0;33mRandom Write:      %s MiB/sec\033[0m\n" "$(echo "${RESULT}/1024" | bc -l)"
    regex='Children see throughput for\s*[0-9]+\s+random writers\s*=\s*([0-9]+\.?[0-9]*)\s*kB\/sec'
    RESULT=$(echo -e "${IOZONE_RESULT}" | grep -oP "${regex}" | tail -n1 | sed -nE "s/${regex}/\1/p")
    printf "\033[0;33mRandom Write:      %s MiB/sec\033[0m\n" "$(echo "${RESULT}/1024" | bc -l)"
}

# Run tests
echo
echo "==== Running Tests ===="
run_iozone_test

# Finish
echo
echo "Done."
exit 0
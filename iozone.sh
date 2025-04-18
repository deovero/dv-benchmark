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

echo
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

# Convert KB/s to MiB/s with 2 decimal places
kb_to_mib() {
    local kb_value="$1"
    echo "scale=2; ${kb_value}/1024" | bc -l
}

# Extract result using regex
extract_result() {
    local result_text="$1"
    local regex="$2"
    echo -e "${result_text}" | grep -oP "${regex}" | tail -n1 | sed -nE "s/${regex}/\1/p"
}

# Function to run IOzone test
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

    local regex_write='Children see throughput for\s*[0-9]+\s+initial writers\s*=\s*([0-9]+\.?[0-9]*)\s*kB\/sec'
    local regex_rand_read='Children see throughput for\s*[0-9]+\s+random readers\s*=\s*([0-9]+\.?[0-9]*)\s*kB\/sec'
    local regex_rand_write='Children see throughput for\s*[0-9]+\s+random writers\s*=\s*([0-9]+\.?[0-9]*)\s*kB\/sec'

    local result_write=$(extract_result "${IOZONE_RESULT}" "${regex_write}")
    local result_rand_read=$(extract_result "${IOZONE_RESULT}" "${regex_rand_read}")
    local result_rand_write=$(extract_result "${IOZONE_RESULT}" "${regex_rand_write}")

    echo
    printf "\033[0;33mSequential Write:  %s MiB/sec\033[0m\n" "$(kb_to_mib "${result_write}")"
    printf "\033[0;33mRandom Read:       %s MiB/sec\033[0m\n" "$(kb_to_mib "${result_rand_read}")"
    printf "\033[0;33mRandom Write:      %s MiB/sec\033[0m\n" "$(kb_to_mib "${result_rand_write}")"
}

# Run tests
echo
echo "==== Running Tests ===="
run_iozone_test

# Cleanup temporary files
find "${WORKDIR}" -type f -name "iozone.*" -delete

# Finish
echo
echo "Done."
exit 0
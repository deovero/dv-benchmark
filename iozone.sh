#!/usr/bin/env bash
#
# Script to test disk IO performance using 'fio'
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

echo "Calling install.sh..."
"${SCRIPT_DIR}/install.sh" iozone3 util-linux grep gawk

export LD_LIBRARY_PATH="${WORKDIR}/usr/lib/x86_64-linux-gnu:${WORKDIR}/usr/lib/x86_64-linux-gnu/ceph:${WORKDIR}/lib/x86_64-linux-gnu"
export PATH="${WORKDIR}/usr/bin:${WORKDIR}/usr/local/bin:/usr/local/bin:/usr/bin:/bin"

# --- Configuration ---
# Set test file path
TEST_FILE="${TEST_FILE:-${WORKDIR}/fio-test.dat}"
# Set test file size
FILE_SIZE="${FILE_SIZE:-20G}"
# Set block size in Kbytes (4k is common for random IO)
BLOCK_SIZE="${BLOCK_SIZE:-4}"
# -------------------

# List block devices
echo
echo "Block Devices:"
lsblk -o NAME,FSTYPE,MOUNTPOINT,SIZE,MODEL
echo

# Print test parameters
echo
echo "Test Parameters:"
echo "- File: $TEST_FILE"
echo "- Size: $FILE_SIZE"
echo "- Block Size: $BLOCK_SIZE"

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
    IOZONE_RESULT=$(
      iozone \
        -i0 \
        -i2 \
        -I \
        -e \
        -s "${FILE_SIZE}" \
        -r "${BLOCK_SIZE}" \
        -f "$TEST_FILE" \
        | tee /dev/tty \
        | grep -P "^\s+\d+\s+${BLOCK_SIZE}\s+\d+\s+\d+\s+\d+\s+\d+"
    )
    SEQ_WRITE=$(echo -e "${IOZONE_RESULT}" | awk '{printf "%.2f", $3/(1024)}')
    RAND_READ=$(echo -e "${IOZONE_RESULT}" | awk '{printf "%.2f", $5/(1024)}')
    RAND_WRITE=$(echo -e "${IOZONE_RESULT}" | awk '{printf "%.2f", $6/(1024)}')
    echo
    echo "Sequential Write: ${SEQ_WRITE} MiB/s"
    echo "Random Read:      ${RAND_READ} MiB/s"
    echo "Random Write:     ${RAND_WRITE} MiB/s"
}

# Run tests
run_iozone_test

# Cleanup to be sure
rm -f "$TEST_FILE"

# Finish
echo
echo "Done."
exit 0
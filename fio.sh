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

echo
echo "==== Installation ====="
"${SCRIPT_DIR}/install.sh" fio sysbench jq util-linux grep gawk

export LD_LIBRARY_PATH="${WORKDIR}/usr/lib/x86_64-linux-gnu:${WORKDIR}/usr/lib/x86_64-linux-gnu/ceph:${WORKDIR}/lib/x86_64-linux-gnu"
export PATH="${WORKDIR}/usr/bin:${WORKDIR}/usr/local/bin:/usr/local/bin:/usr/bin:/bin"

# --- Configuration ---
# Set test file path
TEST_FILE="${TEST_FILE:-${WORKDIR}/fio-test.dat}"
# Set test file size
FILE_SIZE="${FILE_SIZE:-20G}"
# Set block size (4k is common for random IO)
BLOCK_SIZE="${BLOCK_SIZE:-4k}"
# Set run time in seconds
RUN_TIME="${RUN_TIME:-60}"
# Set number of jobs (e.g., 4 or 8 to simulate multiple threads)
NUM_JOBS="${NUM_JOBS:-4}"
# Set queue depth per job, e.g., 16 or 32
IODEPTH="${IODEPTH:-16}"
# -------------------

# List block devices
echo
echo "==== Block Devices ===="
lsblk -o NAME,FSTYPE,MOUNTPOINT,SIZE,MODEL

# Print test parameters
echo
echo "==== Test Parameters ===="
echo "- File: $TEST_FILE"
echo "- Size: $FILE_SIZE"
echo "- Block Size: $BLOCK_SIZE"
echo "- Runtime: $RUN_TIME seconds"
echo "- Jobs: $NUM_JOBS"
echo "- IO Depth: $IODEPTH"

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
run_fio_test() {
    local show_name="$1"
    local rw_type="$2"
    local metric_path="$3"

    FIO_OUTPUT=$(
      fio \
          --name="$rw_type" \
          --filename="$TEST_FILE" \
          --size="$FILE_SIZE" \
          --filesize="$FILE_SIZE" \
          --rw="$rw_type" \
          --bs="$BLOCK_SIZE" \
          --direct=1 \
          --ioengine=libaio \
          --iodepth="$IODEPTH" \
          --numjobs="$NUM_JOBS" \
          --runtime="$RUN_TIME" \
          --group_reporting \
          --norandommap \
          --randrepeat=0 \
          --time_based \
          --output-format=json | jq -r "${metric_path} | round | \"\(.) MiB/s\""
    )
    printf "\033[0;33m%s: %s\033[0m\n" "$show_name" "${FIO_OUTPUT}"
}

echo
echo "==== Running Tests ===="
run_fio_test  'Sequential Write'  'write'      '.jobs[0].write.bw/1024'
#run_fio_test  'Sequential Read'   'read'       '.jobs[0].read.bw/1024'
run_fio_test  'Random Read'       'randread'   '.jobs[0].read.bw/1024'
run_fio_test  'Random Write'      'randwrite'  '.jobs[0].write.bw/1024'

# Cleanup
rm -f "$TEST_FILE"

# Finish
echo
echo "Done."
exit 0
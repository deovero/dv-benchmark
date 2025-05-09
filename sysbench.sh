#!/usr/bin/env bash
#
# Script to test CPU and Memory performance using 'sysbench'
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
"${SCRIPT_DIR}/install.sh" sysbench util-linux grep gawk

export LD_LIBRARY_PATH="${WORKDIR}/usr/lib/x86_64-linux-gnu:${WORKDIR}/usr/lib/x86_64-linux-gnu/ceph:${WORKDIR}/lib/x86_64-linux-gnu"
export PATH="${WORKDIR}/usr/bin:${WORKDIR}/usr/local/bin:/usr/local/bin:/usr/bin:/bin"

# --- Configuration ---
# Set test file path
THREADS="${THREADS:-4}"
RUN_TIME="${RUN_TIME:-60}"
# -------------------

echo
echo "==== CPU info ===="
lscpu

echo
echo "==== Memory info ===="
lsmem

# Print test parameters
echo
echo "==== Test Parameters ===="
echo "- Threads: ${THREADS}"
echo "- Time:    ${RUN_TIME} seconds"

# Function to run FIO test
run_sysbench_test() {
    local test_name="$1"
    local show_name="$2"
    local regex="$3"
    local unit="$4"
    echo
    echo "==== Testing $show_name ===="
    SYSBENCH_RESULT=$(
      sysbench \
        "${test_name}" \
        run \
        --threads="${THREADS}" \
        --time="${RUN_TIME}" \
        | tee /dev/tty
    )
    echo
    RESULT=$(echo -e "${SYSBENCH_RESULT}" | grep -oP "${regex}" | tail -n1 | sed -nE "s/${regex}/\1/p")
    # Print result in yellow
    printf "\033[0;33m%s: %s %s\033[0m\n" "${show_name}" "${RESULT}" "${unit}"
}

# Run tests
run_sysbench_test 'cpu' 'CPU' 'events per second:\s*([0-9]+\.?[0-9]*)' 'events per second'
run_sysbench_test 'memory' 'Memory' 'transferred \(([^\)]+)\)' ''

# Finish
echo
echo "Done."
exit 0
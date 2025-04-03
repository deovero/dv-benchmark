#!/usr/bin/env bash
set -o xtrace -o errexit -o nounset -o pipefail +o history
IFS=$'\n'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${SCRIPT_DIR}/tmp"

mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

export LD_LIBRARY_PATH="${WORKDIR}/usr/lib/x86_64-linux-gnu:${WORKDIR}/usr/lib/x86_64-linux-gnu/ceph"
export PATH="${WORKDIR}/usr/bin:${WORKDIR}/usr/local/bin:/usr/local/bin:/usr/bin:/bin"

# --- Configuration ---
# Set TEST_FILE path on the RAID volume
TEST_FILE="${WORKDIR}/fio-test.dat"
# Set SIZE significantly larger than controller cache (e.g., 10G, 50G)
# Ensure you have enough free space!
FILE_SIZE=20G
# Set BLOCK_SIZE (4k is common for random IO)
BLOCK_SIZE=4k
# Set RUN_TIME (e.g., 120 seconds)
RUN_TIME=120
# Set NUM_JOBS (e.g., 4 or 8 to simulate multiple threads)
NUM_JOBS=4
# Set IODEPTH (queue depth per job, e.g., 16 or 32)
IODEPTH=16

# --- FIO Command ---
fio \
  --name=randread_large \
  --filename=$TEST_FILE \
  --size=$FILE_SIZE \
  --filesize=$FILE_SIZE \
  --rw=randread \
  --bs=$BLOCK_SIZE \
  --direct=1 \
  --ioengine=libaio \
  --iodepth=$IODEPTH \
  --numjobs=$NUM_JOBS \
  --runtime=$RUN_TIME \
  --group_reporting \
  --norandommap \
  --randrepeat=0 \
  --time_based \
  --output-format=json | jq -r '.jobs[0].read.bw/1024 | "Random Read \(.) MiB/s"'

# --- FIO Command ---
fio \
  --name=randwrite_large \
  --filename=$TEST_FILE \
  --size=$FILE_SIZE \
  --filesize=$FILE_SIZE \
  --rw=randwrite \
  --bs=$BLOCK_SIZE \
  --direct=1 \
  --ioengine=libaio \
  --iodepth=$IODEPTH \
  --numjobs=$NUM_JOBS \
  --runtime=$RUN_TIME \
  --group_reporting \
  --norandommap \
  --randrepeat=0 \
  --time_based \
  --output-format=json | jq -r '.jobs[0].write.bw/1024 | "Random Write \(.) MiB/s"'
#  --output-format=normal # Or json for easier parsing

# --- Cleanup ---
rm $TEST_FILE # Remove the large test file afterwards

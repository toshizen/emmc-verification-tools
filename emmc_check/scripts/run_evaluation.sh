#!/bin/bash
# run_evaluation.sh
# Automated eMMC optimization evaluation script
#
# Phase 1: Code optimization (emmc_test mode 0 vs mode 1)
#   Measures write amount reduction from mringf_info frequency change.
#   Verdict: "Total write amount" in result files.
#
# Phase 2: Kernel parameter evaluation (/proc/diskstats)
#   Measures actual block device write rate per profile.
#   NOTE: emmc_test calls fsync() internally, which bypasses the dirty
#         page cache. Kernel parameter changes have no effect on emmc_test
#         output. Use /proc/diskstats to evaluate kernel parameter effects.
#
# Usage: sudo ./run_evaluation.sh [device]
#   device: block device name without /dev/ prefix (default: mmcblk0)

set -e

# ============================================================
# Configuration
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EMMC_TEST="$SCRIPT_DIR/../emmc_test/emmc_test"
DATA_DIR="/opt/emmc_test/data"
RESULT_DIR="$SCRIPT_DIR/../eval_results_$(date '+%Y%m%d_%H%M%S')"
# Auto-detect eMMC device from /proc/diskstats if not specified.
# Matches whole-device names (mmcblkN) excluding partitions (mmcblkNpM).
_default_device() {
    awk '$3~/^mmcblk[0-9]+$/ {print $3; exit}' /proc/diskstats
}
DEVICE="${1:-$(_default_device)}"
if [ -z "$DEVICE" ]; then
    echo "ERROR: No eMMC device found in /proc/diskstats. Specify device as argument."
    echo "Usage: sudo $0 <device>   (e.g. mmcblk0, mmcblk2)"
    exit 1
fi

TEST_DURATION=60      # emmc_test duration in seconds
TEST_THREADS=100      # emmc_test thread count
MEASURE_DURATION=60   # diskstats measurement duration in seconds
SETTLE_TIME=10        # wait time after kernel param change in seconds

# ============================================================
# Save original kernel parameters (restored on exit)
# ============================================================
ORIG_WRITEBACK=$(sysctl -n vm.dirty_writeback_centisecs)
ORIG_EXPIRE=$(sysctl -n vm.dirty_expire_centisecs)
ORIG_BG_RATIO=$(sysctl -n vm.dirty_background_ratio)
ORIG_RATIO=$(sysctl -n vm.dirty_ratio)

restore_params() {
    echo ""
    echo "Restoring original kernel parameters..."
    sysctl -w vm.dirty_writeback_centisecs=$ORIG_WRITEBACK > /dev/null
    sysctl -w vm.dirty_expire_centisecs=$ORIG_EXPIRE       > /dev/null
    sysctl -w vm.dirty_background_ratio=$ORIG_BG_RATIO     > /dev/null
    sysctl -w vm.dirty_ratio=$ORIG_RATIO                   > /dev/null
    echo "  dirty_writeback_centisecs = $ORIG_WRITEBACK ($(($ORIG_WRITEBACK / 100))s)"
    echo "  dirty_expire_centisecs    = $ORIG_EXPIRE ($(($ORIG_EXPIRE / 100))s)"
    echo "  dirty_background_ratio    = $ORIG_BG_RATIO%"
    echo "  dirty_ratio               = $ORIG_RATIO%"
}
trap restore_params EXIT

mkdir -p "$RESULT_DIR"

# ============================================================
# Helper functions
# ============================================================
print_header() {
    echo ""
    echo "=================================================="
    echo "  $1"
    echo "=================================================="
}

apply_params() {
    local writeback=$1 expire=$2 bg_ratio=$3 ratio=$4
    sysctl -w vm.dirty_writeback_centisecs=$writeback > /dev/null
    sysctl -w vm.dirty_expire_centisecs=$expire       > /dev/null
    sysctl -w vm.dirty_background_ratio=$bg_ratio     > /dev/null
    sysctl -w vm.dirty_ratio=$ratio                   > /dev/null
    echo "  dirty_writeback_centisecs = $writeback ($(($writeback / 100))s)"
    echo "  dirty_expire_centisecs    = $expire ($(($expire / 100))s)"
    echo "  dirty_background_ratio    = $bg_ratio%"
    echo "  dirty_ratio               = $ratio%"
}

# Run emmc_test in foreground (used for Phase 1 only).
run_emmc_test() {
    local label=$1 mode=$2
    local mode_str
    [ "$mode" -eq 0 ] && mode_str="BEFORE FIX" || mode_str="AFTER FIX"
    echo ""
    echo "[emmc_test] $label | mode=$mode ($mode_str) | ${TEST_DURATION}s | ${TEST_THREADS} threads"
    rm -rf "$DATA_DIR"/* 2>/dev/null || true
    "$EMMC_TEST" "$mode" "$TEST_DURATION" "$TEST_THREADS" | tee "$RESULT_DIR/emmc_${label}.txt"
}

# Run emmc_test mode 1 (after fix) in background while measuring actual disk
# I/O via /proc/diskstats. Used for Phase 2 to evaluate kernel parameter effects.
#
# NOTE: emmc_test's "Total write amount" is an application-level counter and
#       does NOT change with kernel parameters. Kernel params control when
#       buffered (non-fsync) writes are flushed to the physical device, which
#       is only visible in diskstats. Running emmc_test as the workload ensures
#       a consistent write load across all kernel parameter configurations.
run_combined_test() {
    local label=$1
    local out="$RESULT_DIR/diskstats_${label}.txt"

    echo ""
    echo "[combined] $label | mode=1 (AFTER FIX) bg + diskstats | ${TEST_DURATION}s | ${TEST_THREADS} threads"

    rm -rf "$DATA_DIR"/* 2>/dev/null || true

    # Start emmc_test mode 1 in background
    "$EMMC_TEST" 1 "$TEST_DURATION" "$TEST_THREADS" \
        > "$RESULT_DIR/emmc_bg_${label}.txt" 2>&1 &
    local emmc_pid=$!

    # Wait for file creation to complete before starting diskstats measurement
    sleep 5

    # Measure actual disk write rate via /proc/diskstats
    local sectors_start
    sectors_start=$(awk -v dev="$DEVICE" '$3==dev {print $10}' /proc/diskstats)
    local time_start
    time_start=$(date +%s)

    wait "$emmc_pid"

    local sectors_end
    sectors_end=$(awk -v dev="$DEVICE" '$3==dev {print $10}' /proc/diskstats)
    local time_end
    time_end=$(date +%s)

    local elapsed=$(( time_end - time_start ))
    local diff_sectors=$(( sectors_end - sectors_start ))

    local written_mb
    written_mb=$(awk "BEGIN {printf \"%.2f\", $diff_sectors * 512 / 1024 / 1024}")
    local rate_mbs
    rate_mbs=$(awk "BEGIN {printf \"%.2f\", $diff_sectors * 512 / 1024 / 1024 / $elapsed}")

    echo "  Duration      : ${elapsed}s"
    echo "  Sectors written : $diff_sectors"
    echo "  Written (disk) : ${written_mb} MB"
    echo "  Write rate     : ${rate_mbs} MB/s"
    echo "  emmc_test log  : $RESULT_DIR/emmc_bg_${label}.txt"

    {
        echo "label=$label"
        echo "device=$DEVICE"
        echo "duration=${elapsed}s"
        echo "sectors_written=$diff_sectors"
        echo "written_mb=$written_mb"
        echo "write_rate_mbs=$rate_mbs"
    } | tee "$out"
}

# ============================================================
# Start
# ============================================================
print_header "eMMC Optimization Evaluation"
echo "  Result dir : $RESULT_DIR"
echo "  Device     : /dev/$DEVICE"
echo "  emmc_test  : $EMMC_TEST"
echo ""
echo "  Baseline kernel parameters:"
echo "    dirty_writeback_centisecs = $ORIG_WRITEBACK ($(($ORIG_WRITEBACK / 100))s)"
echo "    dirty_expire_centisecs    = $ORIG_EXPIRE ($(($ORIG_EXPIRE / 100))s)"
echo "    dirty_background_ratio    = $ORIG_BG_RATIO%"
echo "    dirty_ratio               = $ORIG_RATIO%"

# ============================================================
# Phase 1: Code optimization evaluation
#   Kernel params stay at system default throughout Phase 1.
# ============================================================
print_header "Phase 1: Code optimization (default kernel params)"

# Mode 0: write mringf_info on every IO (before fix)
run_emmc_test "mode0_default" 0

# Mode 1: write mringf_info every 30s (after fix)
run_emmc_test "mode1_default" 1

# ============================================================
# Phase 2: Kernel parameter evaluation
#   Read /proc/diskstats to measure actual block device write rate.
#   emmc_test is NOT used here because its internal fsync() calls
#   bypass the dirty page cache, making kernel params have no effect.
# ============================================================
print_header "Phase 2: Kernel parameter evaluation (emmc_test mode 1 + diskstats)"

# 2-1. Default params (baseline for kernel comparison)
echo "--- default ---"
run_combined_test "default"

# 2-2. Balanced profile (recommended)
print_header "Phase 2-2: Balanced profile"
apply_params 1000 6000 15 30
echo "Waiting ${SETTLE_TIME}s for kernel to settle..."
sleep $SETTLE_TIME
run_combined_test "balanced"

# 2-3. Max lifetime profile
print_header "Phase 2-3: Max lifetime profile"
apply_params 3000 12000 20 40
echo "Waiting ${SETTLE_TIME}s for kernel to settle..."
sleep $SETTLE_TIME
run_combined_test "maxlife"

# 2-4. Safety-first profile
print_header "Phase 2-4: Safety-first profile"
apply_params 700 4500 10 20
echo "Waiting ${SETTLE_TIME}s for kernel to settle..."
sleep $SETTLE_TIME
run_combined_test "safety"

# ============================================================
# Summary
# ============================================================
print_header "Summary"

echo "--- Phase 1: Code optimization (emmc_test) ---"
grep "Total write amount" "$RESULT_DIR"/emmc_*.txt

echo ""
echo "--- Phase 2: Kernel parameter effect (diskstats during emmc_test mode 1) ---"
for f in "$RESULT_DIR"/diskstats_*.txt; do
    label=$(awk -F= '/^label/ {print $2}' "$f")
    rate=$(awk -F= '/^write_rate_mbs/ {print $2}' "$f")
    written=$(awk -F= '/^written_mb/ {print $2}' "$f")
    echo "  $label: written = ${written} MB, rate = ${rate} MB/s"
done

echo ""
echo "All results saved to: $RESULT_DIR"
print_header "Evaluation complete"

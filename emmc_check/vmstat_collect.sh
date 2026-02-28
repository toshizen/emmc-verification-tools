#!/bin/sh
# @brief Collect nr_dirty/nr_writeback from /proc/vmstat under a named write condition.
# @usage vmstat_collect.sh <condition_label> [interval_sec] [duration_sec]
# @example vmstat_collect.sh sequential_write 1 60

CONDITION="${1:-unknown}"
INTERVAL="${2:-1}"
DURATION="${3:-0}"   # 0 = run until Ctrl+C

OUTPUT_DIR="./vmstat_data"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
OUTPUT_FILE="${OUTPUT_DIR}/${CONDITION}_${TIMESTAMP}.csv"

echo "=== vmstat dirty/writeback monitor (condition: $CONDITION) ==="
echo "Output: $OUTPUT_FILE"
echo "Interval: ${INTERVAL}s  Duration: ${DURATION}s (0=unlimited)"
echo ""

echo "Timestamp,Elapsed_Sec,nr_dirty,nr_writeback" > "$OUTPUT_FILE"
printf "%-20s %12s %10s %13s\n" "Timestamp" "Elapsed_Sec" "nr_dirty" "nr_writeback"
echo "------------------------------------------------------------"

start_time=$(date +%s)
elapsed=0

collect_once() {
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    nr_dirty=$(awk '/^nr_dirty / {print $2}' /proc/vmstat)
    nr_writeback=$(awk '/^nr_writeback / {print $2}' /proc/vmstat)

    echo "${ts},${elapsed},${nr_dirty},${nr_writeback}" >> "$OUTPUT_FILE"
    printf "%-20s %12d %10d %13d\n" "$ts" "$elapsed" "$nr_dirty" "$nr_writeback"
}

if [ "$DURATION" -eq 0 ]; then
    while true; do
        collect_once
        sleep "$INTERVAL"
    done
else
    end_time=$(($(date +%s) + DURATION))
    while [ "$(date +%s)" -le "$end_time" ]; do
        collect_once
        sleep "$INTERVAL"
    done
fi

echo ""
echo "Saved: $OUTPUT_FILE"

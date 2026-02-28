#!/bin/bash
################################################################################
# emmc_health_check.sh
# eMMCの健全性を定期的にチェック
################################################################################

DEVICE="${1:-mmcblk0}"
LOG_FILE="${2:-/var/log/emmc_health.log}"
STATE_FILE="/tmp/emmc_prev_sectors"

echo "=== eMMC Health Check $(date) ===" | tee -a $LOG_FILE

# デバイスが存在するか確認
if ! grep -q "^.*$DEVICE" /proc/diskstats; then
    echo "ERROR: Device $DEVICE not found" | tee -a $LOG_FILE
    exit 1
fi

# 累積書き込み量（10列目 = 書き込みセクタ数）
SECTORS_WRITTEN=$(awk -v dev="$DEVICE" '$3==dev {print $10}' /proc/diskstats)
MB_WRITTEN=$((SECTORS_WRITTEN / 2048))
GB_WRITTEN=$((MB_WRITTEN / 1024))

echo "Total written: $GB_WRITTEN GB ($MB_WRITTEN MB)" | tee -a $LOG_FILE

# 前回からの差分計算
if [ -f "$STATE_FILE" ]; then
    PREV_SECTORS=$(cat $STATE_FILE)
    PREV_TIME=$(stat -c %Y $STATE_FILE)
    CURR_TIME=$(date +%s)
    ELAPSED=$((CURR_TIME - PREV_TIME))

    if [ $ELAPSED -gt 0 ]; then
        DIFF_SECTORS=$((SECTORS_WRITTEN - PREV_SECTORS))
        DIFF_MB=$((DIFF_SECTORS / 2048))
        DIFF_MB_PER_HOUR=$((DIFF_MB * 3600 / ELAPSED))
        DIFF_MB_PER_DAY=$((DIFF_MB * 86400 / ELAPSED))

        echo "Write rate: $DIFF_MB_PER_HOUR MB/hour, $DIFF_MB_PER_DAY MB/day" | tee -a $LOG_FILE

        # 寿命推定（eMMC 64GB TLC、3000サイクル = 192TB）
        if [ $DIFF_MB_PER_DAY -gt 0 ]; then
            TOTAL_CAPACITY_MB=$((192 * 1024 * 1024))  # 192TB in MB
            LIFETIME_DAYS=$((TOTAL_CAPACITY_MB / DIFF_MB_PER_DAY))
            LIFETIME_YEARS=$((LIFETIME_DAYS / 365))
            LIFETIME_MONTHS=$(( (LIFETIME_DAYS % 365) / 30 ))

            echo "Estimated lifetime: $LIFETIME_YEARS years $LIFETIME_MONTHS months ($LIFETIME_DAYS days)" | tee -a $LOG_FILE

            # 残り寿命の計算
            USED_CAPACITY_MB=$MB_WRITTEN
            REMAINING_CAPACITY_MB=$((TOTAL_CAPACITY_MB - USED_CAPACITY_MB))
            REMAINING_DAYS=$((REMAINING_CAPACITY_MB / DIFF_MB_PER_DAY))
            REMAINING_YEARS=$((REMAINING_DAYS / 365))

            echo "Remaining lifetime: $REMAINING_YEARS years ($REMAINING_DAYS days)" | tee -a $LOG_FILE

            # アラート
            if [ $DIFF_MB_PER_DAY -gt 1000000 ]; then
                echo "⚠️  WARNING: Excessive write detected! (>1TB/day)" | tee -a $LOG_FILE
            elif [ $DIFF_MB_PER_DAY -gt 500000 ]; then
                echo "⚠️  CAUTION: High write rate (>500GB/day)" | tee -a $LOG_FILE
            elif [ $REMAINING_YEARS -lt 1 ]; then
                echo "⚠️  CRITICAL: eMMC lifetime < 1 year!" | tee -a $LOG_FILE
            fi
        fi
    fi
else
    echo "First run. Creating baseline..." | tee -a $LOG_FILE
fi

# 現在の値を保存
echo "$SECTORS_WRITTEN" > $STATE_FILE

# カーネルパラメータの表示
echo "--- Kernel Parameters ---" | tee -a $LOG_FILE
echo "vm.dirty_writeback_centisecs = $(sysctl -n vm.dirty_writeback_centisecs)" | tee -a $LOG_FILE
echo "vm.dirty_expire_centisecs = $(sysctl -n vm.dirty_expire_centisecs)" | tee -a $LOG_FILE
echo "vm.dirty_background_ratio = $(sysctl -n vm.dirty_background_ratio)" | tee -a $LOG_FILE
echo "vm.dirty_ratio = $(sysctl -n vm.dirty_ratio)" | tee -a $LOG_FILE

echo "" | tee -a $LOG_FILE

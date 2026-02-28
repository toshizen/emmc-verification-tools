#!/bin/sh

#/proc/diskstats: Linuxカーネルが管理しているディスクI/Oの統計情報ファイルです。ここから特定のデバイスの数値を抽出する。
#10番目のフィールド: スクリプト内の awk '{print $10}' は、diskstatsの「書き込み成功セクタ数」を指す。

DEVICE="mmcblk2"
INTERVAL=1

# Output file with timestamp
OUTPUT_DIR="./emmc_check_data"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
OUTPUT_FILE="${OUTPUT_DIR}/emmc_write_${TIMESTAMP}.csv"

echo "=== eMMC書き込み監視 (デバイス: $DEVICE) ==="
echo "監視開始: $(date)"
echo "データ出力先: $OUTPUT_FILE"
echo ""

# CSV header (only to file)
echo "Timestamp,Elapsed_Sec,Total_Sectors,Diff_Sectors,Diff_KB,Diff_MB" > "$OUTPUT_FILE"

# Terminal header
echo "Timestamp,Elapsed_Sec,Total_Sectors,Diff_Sectors,Diff_KB,Diff_MB"
echo "-------------------------------------------------------------------"

prev_sectors=""
start_time=$(date +%s)
elapsed=0

while true; do
    stats=$(cat /proc/diskstats | grep " $DEVICE ")
    write_sectors=$(echo $stats | awk '{print $10}')

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ -z "$prev_sectors" ]; then
        # 初回 (baseline)
        csv_line="$timestamp,$elapsed,$write_sectors,0,0,0.00"
        echo "$csv_line" >> "$OUTPUT_FILE"
        echo "$csv_line"
        prev_sectors=$write_sectors
    else
        # 差分計算
        diff_sectors=$((write_sectors - prev_sectors))
        diff_kb=$((diff_sectors / 2))

        # MB単位の計算 (小数点2桁)
        diff_mb_int=$((diff_kb * 100 / 1024))
        diff_mb_decimal=$((diff_mb_int % 100))
        diff_mb_whole=$((diff_mb_int / 100))
        diff_mb=$(printf "%d.%02d" $diff_mb_whole $diff_mb_decimal)

        # CSV line (pure data)
        csv_line="$timestamp,$elapsed,$write_sectors,$diff_sectors,$diff_kb,$diff_mb"

        # CSV output (all data)
        echo "$csv_line" >> "$OUTPUT_FILE"

        # Terminal output (only when write activity detected)
        if [ $diff_kb -gt 0 ]; then
            if [ $diff_kb -gt 100 ]; then
                echo "$csv_line  ★★★ 大量書込"
            elif [ $diff_kb -gt 10 ]; then
                echo "$csv_line  ★"
            else
                echo "$csv_line"
            fi
        fi

        prev_sectors=$write_sectors
    fi

    sleep $INTERVAL
done

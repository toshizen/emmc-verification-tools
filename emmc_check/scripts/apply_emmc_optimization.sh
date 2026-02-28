#!/bin/bash
################################################################################
# apply_emmc_optimization.sh
# eMMC最適化設定を適用するスクリプト
################################################################################

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "eMMC Lifetime Optimization Script"
echo "=================================================="
echo ""

# プロファイル選択
echo "選択してください："
echo "  1) バランス型（推奨）- 寿命約7年、データ欠損リスク60秒"
echo "  2) 最大延命型 - 寿命約10年、データ欠損リスク120秒"
echo "  3) 安全重視型 - 寿命約5年、データ欠損リスク45秒"
echo "  4) 現在の設定を表示"
echo "  5) デフォルトに戻す"
echo ""
read -p "番号を入力 [1-5]: " PROFILE

case $PROFILE in
    1)
        echo -e "${GREEN}バランス型を適用します${NC}"
        WRITEBACK=1000
        EXPIRE=6000
        BG_RATIO=15
        RATIO=30
        ;;
    2)
        echo -e "${YELLOW}最大延命型を適用します（データ欠損リスク増）${NC}"
        WRITEBACK=3000
        EXPIRE=12000
        BG_RATIO=20
        RATIO=40
        ;;
    3)
        echo -e "${GREEN}安全重視型を適用します${NC}"
        WRITEBACK=700
        EXPIRE=4500
        BG_RATIO=10
        RATIO=20
        ;;
    4)
        echo "=== 現在の設定 ==="
        echo -n "vm.dirty_writeback_centisecs = "
        sysctl -n vm.dirty_writeback_centisecs
        echo -n "vm.dirty_expire_centisecs = "
        sysctl -n vm.dirty_expire_centisecs
        echo -n "vm.dirty_background_ratio = "
        sysctl -n vm.dirty_background_ratio
        echo -n "vm.dirty_ratio = "
        sysctl -n vm.dirty_ratio
        exit 0
        ;;
    5)
        echo -e "${YELLOW}デフォルト設定に戻します${NC}"
        WRITEBACK=500
        EXPIRE=3000
        BG_RATIO=10
        RATIO=20
        ;;
    *)
        echo -e "${RED}無効な選択です${NC}"
        exit 1
        ;;
esac

# 確認
echo ""
echo "=== 適用する設定 ==="
echo "vm.dirty_writeback_centisecs = $WRITEBACK ($(($WRITEBACK / 100))秒)"
echo "vm.dirty_expire_centisecs = $EXPIRE ($(($EXPIRE / 100))秒)"
echo "vm.dirty_background_ratio = $BG_RATIO%"
echo "vm.dirty_ratio = $RATIO%"
echo ""
read -p "この設定を適用しますか？ [y/N]: " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "キャンセルしました"
    exit 0
fi

# 一時的に適用
echo ""
echo "=== 設定を適用中 ==="
sudo sysctl -w vm.dirty_writeback_centisecs=$WRITEBACK
sudo sysctl -w vm.dirty_expire_centisecs=$EXPIRE
sudo sysctl -w vm.dirty_background_ratio=$BG_RATIO
sudo sysctl -w vm.dirty_ratio=$RATIO

echo -e "${GREEN}✓ 一時的な設定が完了しました${NC}"

# 恒久的な設定
echo ""
read -p "再起動後も有効にしますか？ [y/N]: " PERMANENT

if [ "$PERMANENT" = "y" ] || [ "$PERMANENT" = "Y" ]; then
    CONFIG_FILE="/etc/sysctl.d/99-emmc-optimize.conf"

    echo "=== 恒久設定ファイルを作成中 ==="
    sudo tee $CONFIG_FILE > /dev/null <<EOF
# eMMC寿命延長のための最適化設定
# Generated: $(date)
# Profile: $(case $PROFILE in 1) echo "バランス型";; 2) echo "最大延命型";; 3) echo "安全重視型";; 5) echo "デフォルト";; esac)

# 書き込みチェック間隔
vm.dirty_writeback_centisecs = $WRITEBACK

# ダーティページの有効期限
vm.dirty_expire_centisecs = $EXPIRE

# バックグラウンド書き込み開始閾値
vm.dirty_background_ratio = $BG_RATIO

# 強制同期書き込み閾値
vm.dirty_ratio = $RATIO
EOF

    echo -e "${GREEN}✓ $CONFIG_FILE を作成しました${NC}"
fi

echo ""
echo "=================================================="
echo -e "${GREEN}設定が完了しました！${NC}"
echo "=================================================="
echo ""
echo "次のステップ："
echo "  1. システムの動作を監視してください"
echo "  2. eMMC書き込み量を測定してください:"
echo "     iostat -x 10 /dev/mmcblk0"
echo "  3. 問題があれば、このスクリプトで設定を変更できます"
echo ""

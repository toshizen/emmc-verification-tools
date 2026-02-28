# eMMC寿命延長評価

eMMC最適化のための総合ツールセット

## 📁 ディレクトリ構成

```
./emmc_check/
├── README.md                    # このファイル
├── emmc_test/                   # 効果検証ツール
│   ├── main.c                   # ソースコード
│   ├── Makefile                 # ビルド設定
│   ├── emmc_test                # 実行ファイル
│   └── README.md                # 使用方法
├── docs/                        # ドキュメント
│   └── emmc_optimization_guide.md   # 最適化ガイド
└── scripts/                     # 運用スクリプト
    ├── apply_emmc_optimization.sh   # カーネルパラメータ最適化
    └── emmc_health_check.sh         # eMMCヘルスチェック
```

---

## 🎯 目的

eMMC急速劣化問題に対する対策：

1. **コード最適化**: ring_infoの書き込み頻度を削減（各IO毎 → 30秒毎）
2. **カーネル最適化**: Linuxカーネルパラメータでさらに書き込み削減
3. **継続監視**: eMMCの健全性を定期的にチェック

### 期待される効果

| 対策 | eMMC寿命 | 削減率 |
|------|---------|--------|
| 現状（修正前） | 約6ヶ月 | - |
| コード最適化のみ | 約5年 | 96% |
| コード最適化 + カーネル最適化 | **約7-10年** | **97-98%** |

---

## 🚀 クイックスタート

### 1. コード最適化の効果検証

```bash
cd emmc_test

# 修正前の動作をシミュレート（60秒）
sudo ./emmc_test 0 60 100

# 修正後の動作をシミュレート（60秒）
sudo ./emmc_test 1 60 100

# 結果比較
# Total write amount を確認
```

**期待結果**:
- モード0（修正前）: 約2,500 MB
- モード1（修正後）: 約85 MB
- **削減率: 約96%**

詳細は [`emmc_test/README.md`](emmc_test/README.md) を参照。

---

### 2. カーネルパラメータ最適化

```bash
cd scripts

# インタラクティブに設定
sudo ./apply_emmc_optimization.sh

# プロファイル選択：
#   1) バランス型（推奨） - 寿命7年、データ欠損リスク60秒
#   2) 最大延命型 - 寿命10年、データ欠損リスク120秒
#   3) 安全重視型 - 寿命5年、データ欠損リスク45秒
```

**推奨**: まず「1) バランス型」を選択

詳細は [`docs/emmc_optimization_guide.md`](docs/emmc_optimization_guide.md) を参照。

---

### 3. eMMCヘルスチェック

```bash
cd scripts

# 手動実行
sudo ./emmc_health_check.sh

# 定期実行設定（毎日3時）
sudo crontab -e
# 以下を追加：
0 3 * * * emmc_check/scripts/emmc_health_check.sh
```

---

## 📊 実測結果（参考）

### emmc_testによる測定

```
モード0（修正前）:
  Total write amount: 2493.83 MB / 60秒

モード1（修正後）:
  Total write amount: 85.06 MB / 60秒

削減率: 96.6%
```

### 実環境でのディスク書き込み量

```
モード0（修正前）:
  約1,124 MB / 60秒 = 約18.7 MB/秒

モード1（修正後）:
  約189 MB / 60秒 = 約3.2 MB/秒

削減率: 83%
```

差分はOSのジャーナリング、メタデータ更新によるもの。



## 🔧 各ツールの詳細

### emmc_test

コード最適化の修正前後の動作を模擬し、書き込み量を比較測定するツール。

- **モード0**: 各datファイル更新後に毎回mringf_info更新（修正前）
- **モード1**: 30秒毎に1回だけmringf_info更新（修正後）

詳細: [`emmc_test/README.md`](emmc_test/README.md)

### apply_emmc_optimization.sh

Linuxカーネルパラメータを対話的に設定するスクリプト。

主な設定項目：
- `vm.dirty_writeback_centisecs`: 書き込みチェック間隔
- `vm.dirty_expire_centisecs`: ダーティページの有効期限
- `vm.dirty_background_ratio`: バックグラウンド書き込み開始閾値
- `vm.dirty_ratio`: 強制同期書き込み閾値

### emmc_health_check.sh

eMMCの書き込み量を測定し、寿命を推定するスクリプト。

出力情報：
- 累積書き込み量
- 1日あたりの書き込み量
- 推定寿命（年数）
- 残り寿命

---

## 📖 ドキュメント

### [docs/evaluation_checklist.md](docs/evaluation_checklist.md)

コード最適化・カーネルパラメータ変更を含む総合評価チェックリスト。各フェーズの計測手順・判定基準・記録欄を収録。

### [docs/emmc_optimization_guide.md](docs/emmc_optimization_guide.md)

包括的な最適化ガイド。以下の内容を含む：

1. カーネルパラメータの詳細説明
2. 推奨設定（3つのプロファイル）
3. 設定方法と適用手順
4. 効果測定方法
5. リスク評価
6. その他の最適化手法
7. モニタリング方法
8. 実装チェックリスト

---

## ⚠️ 注意事項

### データ欠損リスク

カーネルパラメータ最適化により、停電時のデータ欠損リスクが増加します：

| 設定 | データ欠損リスク |
|------|----------------|
| デフォルト | 最大30秒 |
| バランス型 | 最大60秒 |
| 最大延命型 | 最大120秒 |

**対策**:
- UPSの導入
- 重要データの明示的なfsync()
- クラウドへの定期バックアップ


---

## 🤝 サポート

質問や問題があれば、以下を参照：

1. [`emmc_test/README.md`](emmc_test/README.md) - emmc_testの使い方
2. [`docs/emmc_optimization_guide.md`](docs/emmc_optimization_guide.md) - 詳細な最適化ガイド
3. [`docs/evaluation_checklist.md`](docs/evaluation_checklist.md) - 評価チェックリスト

---

## 📝 履歴

- 2026-02-26: 初版作成
  - emmc_test実装
  - カーネルパラメータ最適化スクリプト作成
  - 最適化ガイド作成
  - ヘルスチェックスクリプト作成

# eMMC Write Test

## 概要

eMMCコード最適化の効果を検証するための実験プログラムです。
ring_infoの書き込み頻度削減による書き込み量の違いを測定します。

## 仕様

- **5000個のdatファイル**: `/opt/emmc_test/data/00000.dat` ~ `04999.dat` (各64 bytes)
- **ring_infoファイル**: `/opt/emmc_test/data/ring_info` (440KB)
- **スレッドプール方式**: 指定した数のスレッドで5000ファイルを分担処理
- **テストモード**:
  - **モード0 **: 各datファイル更新後に毎回ring_infoを更新
  - **モード1 **: 30秒周期で1回だけring_infoを更新

## ビルド方法

shizenboxプロジェクトのビルドシステムに統合されています。

```bash
cd /home/sato/git/shizenbox/review
make
```

または個別ビルド：

```bash
cd /home/sato/git/shizenbox/review/src/app/emmc_test
make
```

## 準備

```bash
# /opt/emmc_test/data ディレクトリを作成
sudo mkdir -p /opt/emmc_test/data
sudo chown $USER:$USER /opt/emmc_test/data
```

## 実行方法

### 基本実行

```bash
# デフォルト: モード1 (修正後), 300秒, 100スレッド
sudo ./emmc_test

# モード0 (修正前) で60秒実行
sudo ./emmc_test 0 60

# モード1 (修正後) で120秒、50スレッドで実行
sudo ./emmc_test 1 120 50
```

### 引数

```
./emmc_test [mode] [duration] [num_threads]
  mode:        0 (修正前), 1 (修正後, デフォルト)
  duration:    テスト実行時間（秒）, デフォルト300秒
  num_threads: 書き込みスレッド数, デフォルト100
               (1 ~ 5000の範囲、各スレッドが複数ファイルを担当)
```

### スレッド数の目安

| スレッド数 | 1スレッド当たりのファイル数 | 推奨用途 |
|-----------|--------------------------|---------|
| 10 | 500ファイル | 軽量テスト |
| 50 | 100ファイル | 標準テスト |
| 100 | 50ファイル | デフォルト（推奨） |
| 500 | 10ファイル | 高負荷テスト |
| 1000 | 5ファイル | 最大負荷（要注意） |

**注意**: スレッド数が多すぎるとシステムリソースを圧迫します。ulimit -u の値を確認してください。

## 出力例

```
=== eMMC Write Test ===
Mode: 1 (AFTER FIX)
Files: 5000
Threads: 100 (each handles ~50 files)
Data dir: /opt/emmc_test/data
Info size: 440 KB
Test duration: 300 seconds
==================================

Creating 5000 dat files...
  Created 1000 files...
  Created 2000 files...
  Created 3000 files...
  Created 4000 files...
  Created 5000 files...
Done.

Starting write threads...
  Started 100 threads...
Done.

Test running... Press Ctrl+C to stop, or wait 300 seconds.

[10 sec] DAT: 45123 writes (2817 KB), INFO: 0 writes (0 KB), Total: 2817 KB
[20 sec] DAT: 46891 writes (2930 KB), INFO: 0 writes (0 KB), Total: 2930 KB
[30 sec] Flushed: 92014 files updated, info written
[30 sec] DAT: 47256 writes (2953 KB), INFO: 1 writes (440 KB), Total: 3393 KB
...

=== Test Results ===
Total DAT writes: 1500000 (91.55 MB)
Total INFO writes: 10 (4.30 MB)
Total write amount: 95.85 MB
====================
```

## 比較テスト

### 短時間テスト (60秒ずつ)

```bash
# 修正前
sudo ./emmc_test 0 60 100 > result_before_60s.txt

# クリーンアップ
sudo rm -rf /opt/emmc_test/data/*

# 修正後
sudo ./emmc_test 1 60 100 > result_after_60s.txt

# 結果比較
grep "Total write amount" result_*.txt
```

### 長時間テスト (300秒 = 5分)

```bash
# 修正前
sudo ./emmc_test 0 300 100 > result_before_300s.txt
sudo rm -rf /opt/emmc_test/data/*

# 修正後
sudo ./emmc_test 1 300 100 > result_after_300s.txt

# 結果比較
grep "Total write amount" result_*.txt
```

## 期待される結果

60秒テストの場合：

| モード | DAT書き込み | INFO書き込み回数 | INFO書き込み量 | 総書き込み量 |
|-------|-----------|----------------|--------------|------------|
| 0  | ~90 MB | ~9,000回 | ~3,900 MB | **~4,000 MB** |
| 1  | ~90 MB | 2回 | ~0.9 MB | **~91 MB** |

**削減率**: 約98%の書き込み量削減

## トラブルシューティング

### スレッド作成失敗

```
Failed to create thread 250: Resource temporarily unavailable
```

→ スレッド数を減らしてください：
```bash
sudo ./emmc_test 1 60 50  # 100 → 50に変更
```

### ファイル作成失敗

```
Failed to create /opt/emmc_test/data/00000.dat: Permission denied
```

→ ディレクトリのパーミッションを確認：
```bash
sudo chown -R $USER:$USER /opt/emmc_test
```

## クリーンアップ

```bash
# テストデータ削除
sudo rm -rf /opt/emmc_test/data/*

# 完全削除
sudo rm -rf /opt/emmc_test
```

## 実装の詳細

- 各スレッドは担当するファイル群を順次更新し続けます
- モード0では各ファイル更新後にfsync()付きでinfo更新
- モード1では30秒毎に1回だけinfo更新

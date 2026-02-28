#!/usr/bin/env python3
"""
Compare nr_dirty / nr_writeback across multiple write-condition CSV files.

Usage:
    python3 plot_vmstat_compare.py <csv1> [csv2 ...] [-o output.png]

Each CSV must have columns: Timestamp, Elapsed_Sec, nr_dirty, nr_writeback
(produced by vmstat_collect.sh)
"""

import sys
import argparse
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker


# ── colour cycle (up to 8 conditions) ────────────────────────────────────────
COLORS = ["tab:blue", "tab:orange", "tab:green", "tab:red",
          "tab:purple", "tab:brown", "tab:pink", "tab:gray"]


def load_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    required = {"Elapsed_Sec", "nr_dirty", "nr_writeback"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"{path}: missing columns {missing}")
    return df


def condition_label(path: str) -> str:
    """Derive a human-readable label from the filename."""
    stem = Path(path).stem          # e.g. sequential_write_20260228_120000
    parts = stem.rsplit("_", 2)     # strip trailing timestamp fields
    return parts[0] if len(parts) >= 3 else stem


def plot(datasets: list[tuple[str, pd.DataFrame]], output: str) -> None:
    fig, axes = plt.subplots(3, 1, figsize=(14, 12))
    fig.suptitle("vmstat nr_dirty / nr_writeback – write condition comparison",
                 fontsize=15, fontweight="bold")

    ax_dirty, ax_wb, ax_peak = axes

    for idx, (label, df) in enumerate(datasets):
        color = COLORS[idx % len(COLORS)]
        ax_dirty.plot(df["Elapsed_Sec"], df["nr_dirty"],
                      color=color, linewidth=1.5, label=label, alpha=0.85)
        ax_wb.plot(df["Elapsed_Sec"], df["nr_writeback"],
                   color=color, linewidth=1.5, label=label, alpha=0.85)

    # Panel 3: peak (max) bar chart per condition
    labels   = [lbl for lbl, _ in datasets]
    max_dirty = [df["nr_dirty"].max()      for _, df in datasets]
    max_wb    = [df["nr_writeback"].max()  for _, df in datasets]
    x = range(len(labels))
    width = 0.35
    bars1 = ax_peak.bar([i - width / 2 for i in x], max_dirty,
                        width, label="nr_dirty peak",     color="steelblue", alpha=0.8)
    bars2 = ax_peak.bar([i + width / 2 for i in x], max_wb,
                        width, label="nr_writeback peak", color="darkorange", alpha=0.8)
    ax_peak.set_xticks(list(x))
    ax_peak.set_xticklabels(labels, rotation=15, ha="right")
    ax_peak.bar_label(bars1, fmt="%d", padding=3, fontsize=8)
    ax_peak.bar_label(bars2, fmt="%d", padding=3, fontsize=8)

    # Formatting
    for ax, title, ylabel in [
        (ax_dirty, "nr_dirty over time (pages)",     "nr_dirty (pages)"),
        (ax_wb,    "nr_writeback over time (pages)",  "nr_writeback (pages)"),
        (ax_peak,  "Peak values per condition",        "pages"),
    ]:
        ax.set_title(title, fontsize=12)
        ax.set_ylabel(ylabel, fontsize=10)
        ax.grid(True, alpha=0.3)
        ax.legend(fontsize=9)
        ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda v, _: f"{int(v):,}"))

    ax_dirty.set_xlabel("Elapsed Time (s)", fontsize=10)
    ax_wb.set_xlabel("Elapsed Time (s)", fontsize=10)
    ax_peak.set_xlabel("Write condition", fontsize=10)

    fig.subplots_adjust(left=0.09, right=0.97, top=0.93, bottom=0.08, hspace=0.42)
    plt.savefig(output, dpi=150)
    print(f"Graph saved: {output}")


def print_stats(datasets: list[tuple[str, pd.DataFrame]]) -> None:
    col_w = max(len(lbl) for lbl, _ in datasets) + 2
    header = f"{'Condition':<{col_w}} {'duration(s)':>11} {'dirty_max':>10} {'dirty_avg':>10} {'wb_max':>8} {'wb_avg':>8}"
    print("\n" + "=" * len(header))
    print("STATISTICS")
    print("=" * len(header))
    print(header)
    print("-" * len(header))
    for label, df in datasets:
        print(f"{label:<{col_w}} "
              f"{int(df['Elapsed_Sec'].max()):>11} "
              f"{int(df['nr_dirty'].max()):>10,} "
              f"{df['nr_dirty'].mean():>10.1f} "
              f"{int(df['nr_writeback'].max()):>8,} "
              f"{df['nr_writeback'].mean():>8.1f}")
    print("=" * len(header) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare nr_dirty/nr_writeback across write-condition CSVs")
    parser.add_argument("csv_files", nargs="+", help="CSV files (one per condition)")
    parser.add_argument("-o", "--output", default="vmstat_comparison.png",
                        help="Output PNG filename (default: vmstat_comparison.png)")
    args = parser.parse_args()

    datasets: list[tuple[str, pd.DataFrame]] = []
    for path in args.csv_files:
        if not Path(path).exists():
            print(f"Error: not found: {path}", file=sys.stderr)
            sys.exit(1)
        try:
            df = load_csv(path)
        except (ValueError, pd.errors.ParserError) as exc:
            print(f"Error loading {path}: {exc}", file=sys.stderr)
            sys.exit(1)
        datasets.append((condition_label(path), df))

    try:
        plot(datasets, args.output)
        print_stats(datasets)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        print("Ensure pandas and matplotlib are installed: pip3 install pandas matplotlib",
              file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

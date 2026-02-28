#!/usr/bin/env python3

"""
eMMC write monitoring data comparison visualization script
Compare before/after parameter changes and show write rate reduction
Usage: python3 plot_emmc_compare.py <before_csv> <after_csv>
"""

import sys
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

def plot_comparison(before_csv, after_csv):
    """Compare two eMMC write monitoring datasets"""

    # Read CSV files
    df_before = pd.read_csv(before_csv)
    df_after = pd.read_csv(after_csv)

    # Create output filename
    output_png = "emmc_comparison.png"

    # Create figure with subplots
    fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(14, 12))
    fig.suptitle('eMMC Write Comparison - Before vs After Parameter Change',
                 fontsize=16, fontweight='bold')

    # Plot 1: Write rate comparison (KB)
    ax1.plot(df_before['Elapsed_Sec'], df_before['Diff_KB'],
             'r-', linewidth=2, label='Before (修正前)', alpha=0.7)
    ax1.plot(df_after['Elapsed_Sec'], df_after['Diff_KB'],
             'b-', linewidth=2, label='After (修正後)', alpha=0.7)
    ax1.set_xlabel('Elapsed Time (seconds)', fontsize=12)
    ax1.set_ylabel('Write Rate (KB/interval)', fontsize=12)
    ax1.set_title('Write Rate Comparison (KB)', fontsize=14)
    ax1.grid(True, alpha=0.3)
    ax1.legend(fontsize=11)

    # Plot 2: Cumulative write comparison (MB)
    before_cumsum = df_before['Diff_MB'].cumsum()
    after_cumsum = df_after['Diff_MB'].cumsum()

    ax2.plot(df_before['Elapsed_Sec'], before_cumsum,
             'r-', linewidth=2, label='Before (修正前)', alpha=0.7)
    ax2.plot(df_after['Elapsed_Sec'], after_cumsum,
             'b-', linewidth=2, label='After (修正後)', alpha=0.7)
    ax2.set_xlabel('Elapsed Time (seconds)', fontsize=12)
    ax2.set_ylabel('Cumulative Write (MB)', fontsize=12)
    ax2.set_title('Cumulative Write Amount Comparison', fontsize=14)
    ax2.grid(True, alpha=0.3)
    ax2.legend(fontsize=11)

    # Plot 3: Write rate histogram comparison
    ax3.hist(df_before['Diff_KB'], bins=50, alpha=0.5, color='red',
             label='Before (修正前)', range=(0, 1000))
    ax3.hist(df_after['Diff_KB'], bins=50, alpha=0.5, color='blue',
             label='After (修正後)', range=(0, 1000))
    ax3.set_xlabel('Write Rate (KB/interval)', fontsize=12)
    ax3.set_ylabel('Frequency', fontsize=12)
    ax3.set_title('Write Rate Distribution (0-1000 KB)', fontsize=14)
    ax3.grid(True, alpha=0.3, axis='y')
    ax3.legend(fontsize=11)

    # Adjust layout and save
    fig.subplots_adjust(left=0.08, right=0.95, top=0.94, bottom=0.06, hspace=0.35)
    plt.savefig(output_png, dpi=150)
    print(f"Comparison graph generated: {output_png}")

    # Calculate and display statistics
    print("\n" + "="*60)
    print("COMPARISON STATISTICS")
    print("="*60)

    # Before stats
    before_duration = df_before['Elapsed_Sec'].max()
    before_total_mb = df_before['Diff_MB'].sum()
    before_avg_kb = df_before['Diff_KB'].mean()
    before_max_kb = df_before['Diff_KB'].max()

    # After stats
    after_duration = df_after['Elapsed_Sec'].max()
    after_total_mb = df_after['Diff_MB'].sum()
    after_avg_kb = df_after['Diff_KB'].mean()
    after_max_kb = df_after['Diff_KB'].max()

    print(f"\n【Before (修正前)】")
    print(f"  Duration:          {before_duration} seconds")
    print(f"  Total write:       {before_total_mb:.2f} MB")
    print(f"  Average rate:      {before_avg_kb:.2f} KB/sec")
    print(f"  Max rate:          {before_max_kb:.2f} KB/sec")

    print(f"\n【After (修正後)】")
    print(f"  Duration:          {after_duration} seconds")
    print(f"  Total write:       {after_total_mb:.2f} MB")
    print(f"  Average rate:      {after_avg_kb:.2f} KB/sec")
    print(f"  Max rate:          {after_max_kb:.2f} KB/sec")

    # Reduction calculation
    if before_total_mb > 0:
        mb_reduction = ((before_total_mb - after_total_mb) / before_total_mb) * 100
    else:
        mb_reduction = 0

    if before_avg_kb > 0:
        avg_reduction = ((before_avg_kb - after_avg_kb) / before_avg_kb) * 100
    else:
        avg_reduction = 0

    print(f"\n{'='*60}")
    print(f"【IMPROVEMENT】")
    print(f"{'='*60}")
    print(f"  Total write reduction:   {mb_reduction:+.1f}% ({before_total_mb:.2f} → {after_total_mb:.2f} MB)")
    print(f"  Average rate reduction:  {avg_reduction:+.1f}% ({before_avg_kb:.2f} → {after_avg_kb:.2f} KB/sec)")
    print(f"{'='*60}\n")

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 plot_emmc_compare.py <before_csv> <after_csv>")
        print("Example: python3 plot_emmc_compare.py before.csv after.csv")
        sys.exit(1)

    before_csv = sys.argv[1]
    after_csv = sys.argv[2]

    if not Path(before_csv).exists():
        print(f"Error: File not found: {before_csv}")
        sys.exit(1)

    if not Path(after_csv).exists():
        print(f"Error: File not found: {after_csv}")
        sys.exit(1)

    try:
        plot_comparison(before_csv, after_csv)
    except Exception as e:
        print(f"Error: {e}")
        print("Please ensure pandas and matplotlib are installed:")
        print("  pip3 install pandas matplotlib")
        sys.exit(1)

if __name__ == '__main__':
    main()

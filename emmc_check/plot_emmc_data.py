#!/usr/bin/env python3

"""
eMMC write monitoring data visualization script
Usage: python3 plot_emmc_data.py <csv_file>
"""

import sys
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

def plot_emmc_data(csv_file):
    """Plot eMMC write monitoring data from CSV file"""

    # Read CSV file
    df = pd.read_csv(csv_file)

    # Create output filename
    output_png = csv_file.replace('.csv', '.png')

    # Create figure with subplots
    fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(14, 12))
    fig.suptitle(f'eMMC Write Monitor - {Path(csv_file).name}', fontsize=14, fontweight='bold')

    # Plot 1: Cumulative write sectors
    ax1.plot(df['Elapsed_Sec'], df['Total_Sectors'], 'b-', linewidth=2, marker='o', markersize=3)
    ax1.set_xlabel('Elapsed Time (seconds)')
    ax1.set_ylabel('Total Write Sectors')
    ax1.set_title('Cumulative Write Sectors')
    ax1.grid(True, alpha=0.3)

    # Plot 2: Write rate in KB
    ax2.plot(df['Elapsed_Sec'], df['Diff_KB'], 'g-', linewidth=2, marker='o', markersize=3)
    ax2.set_xlabel('Elapsed Time (seconds)')
    ax2.set_ylabel('Write Rate (KB/interval)')
    ax2.set_title('Write Rate (KB)')
    ax2.grid(True, alpha=0.3)

    # Highlight high write activity
    high_write = df[df['Diff_KB'] > 100]
    if not high_write.empty:
        ax2.scatter(high_write['Elapsed_Sec'], high_write['Diff_KB'],
                   color='red', s=100, alpha=0.6, label='High write (>100KB)', zorder=5)
        ax2.legend()

    # Plot 3: Write rate in MB
    ax3.plot(df['Elapsed_Sec'], df['Diff_MB'], 'r-', linewidth=2, marker='o', markersize=3)
    ax3.set_xlabel('Elapsed Time (seconds)')
    ax3.set_ylabel('Write Rate (MB/interval)')
    ax3.set_title('Write Rate (MB)')
    ax3.grid(True, alpha=0.3)

    # Adjust layout and save
    fig.subplots_adjust(left=0.08, right=0.95, top=0.94, bottom=0.06, hspace=0.3)
    plt.savefig(output_png, dpi=150)
    print(f"Graph generated successfully: {output_png}")

    # Display statistics
    print("\n=== Statistics ===")
    print(f"Total duration: {df['Elapsed_Sec'].max()} seconds")
    print(f"Total sectors written: {df['Total_Sectors'].iloc[-1] - df['Total_Sectors'].iloc[0]:,}")
    print(f"Total KB written: {df['Diff_KB'].sum():,.2f} KB")
    print(f"Total MB written: {df['Diff_MB'].sum():.2f} MB")
    print(f"Average write rate: {df['Diff_KB'].mean():.2f} KB/sec")
    print(f"Max write rate: {df['Diff_KB'].max():.2f} KB/sec")
    print(f"Number of high writes (>100KB): {len(high_write)}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 plot_emmc_data.py <csv_file>")
        print("Example: python3 plot_emmc_data.py emmc_check_data/emmc_write_20260226_123456.csv")
        sys.exit(1)

    csv_file = sys.argv[1]

    if not Path(csv_file).exists():
        print(f"Error: File not found: {csv_file}")
        sys.exit(1)

    try:
        plot_emmc_data(csv_file)
    except Exception as e:
        print(f"Error: {e}")
        print("Please ensure pandas and matplotlib are installed:")
        print("  pip3 install pandas matplotlib")
        sys.exit(1)

if __name__ == '__main__':
    main()

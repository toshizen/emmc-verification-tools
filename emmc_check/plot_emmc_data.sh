#!/bin/sh

# Usage: ./plot_emmc_data.sh <csv_file>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <csv_file>"
    echo "Example: $0 emmc_check_data/emmc_write_20260226_123456.csv"
    exit 1
fi

CSV_FILE="$1"

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File not found: $CSV_FILE"
    exit 1
fi

OUTPUT_PNG="${CSV_FILE%.csv}.png"

# Generate gnuplot script
cat > /tmp/gnuplot_script.gp << 'EOF'
set datafile separator ","
set terminal pngcairo size 1200,800 enhanced font 'Arial,12'
set output output_file

set multiplot layout 2,1 title "eMMC Write Monitor" font ",14"

# Plot 1: Cumulative write sectors over time
set xlabel "Elapsed Time (seconds)"
set ylabel "Total Write Sectors"
set title "Cumulative Write Sectors"
set grid
plot input_file using 2:3 with linespoints title "Total Sectors" lw 2

# Plot 2: Write rate (KB/sec)
set xlabel "Elapsed Time (seconds)"
set ylabel "Write Rate (KB/interval)"
set title "Write Rate"
set grid
plot input_file using 2:5 with linespoints title "Diff KB" lw 2

unset multiplot
EOF

gnuplot -e "input_file='$CSV_FILE'; output_file='$OUTPUT_PNG'" /tmp/gnuplot_script.gp

if [ $? -eq 0 ]; then
    echo "Graph generated successfully: $OUTPUT_PNG"
    rm -f /tmp/gnuplot_script.gp
else
    echo "Error: gnuplot failed. Please install gnuplot."
    echo "  Ubuntu/Debian: sudo apt-get install gnuplot"
    exit 1
fi

#!/bin/sh
# Clean CSV by removing star markers

if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_csv>"
    exit 1
fi

INPUT="$1"
OUTPUT="${INPUT%.csv}_cleaned.csv"

sed 's/  ★.*$//' "$INPUT" > "$OUTPUT"
echo "Cleaned CSV created: $OUTPUT"

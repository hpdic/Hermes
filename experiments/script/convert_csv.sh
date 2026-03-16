#!/bin/bash

# ==============================================================================
# @file convert_csv.sh
# @author Dongfang Zhao (dzhao@uw.edu)
#
# @brief Data preprocessing and CSV conversion script for Hermes evaluations.
#
# @details
# This utility transforms raw experimental datasets into structured CSV files 
# tailored for the Hermes database ingestion pipeline. It cleans the raw input 
# by stripping non numeric characters and rounding floating point values to 
# integers. Every record is sequentially assigned a unique identifier and a 
# group identifier. The group identifier is calculated mathematically based on 
# the provided pack size parameter. This ensures the data aligns perfectly for 
# vectorized homomorphic encryption batching.
#
# @parameters
# * pack_size (optional): The number of data rows to bundle into a single 
#   encryption group. Defaults to 4096. The absolute maximum limit is 8192.
#
# @dependencies
# * awk: Required for high performance stream parsing and mathematical rounding.
#
# @usage
# bash convert_csv.sh [pack_size]
#
# @example
# bash convert_csv.sh 1024
# ==============================================================================

set -e

echo "[*] Converting raw data to CSV format..."

# Default group size
if [[ -z "$1" ]]; then
  echo "Usage: $0 <pack_size>"
  echo "  ⚠️ Max pack_size = 8192; recommended 4096 will be used."
fi

PACK_SIZE=${1:-4096}

if (( PACK_SIZE > 8192 )); then
  echo "Error: pack_size must be ≤ 8192"
  exit 1
fi

TMP_DIR="$HOME/hpdic/Hermes/tmp"
mkdir -p "$TMP_DIR"

convert() {
    local input=$1
    local output=$2
    local colname=$3

    echo "[*] Processing $input → $output"

    awk -v gsize="$PACK_SIZE" -v colname="$colname" '
    BEGIN {
        OFS=",";
        print "id", "group_id", colname;
    }
    {
        gsub(/,/, "", $0);           # remove commas
        gsub(/[^0-9.\-]/, "", $0);   # remove non-numeric
        if ($0 ~ /^[0-9.\-]+$/) {
            val = int($0 + 0.5);     # round float to int
            id = ++count;
            gid = int((id - 1) / gsize);
            print id, gid, val;
        }
    }
    ' "$input" > "$output"
}

convert "$HOME/hpdic/Hermes/experiments/dataset/bitcoin" "$TMP_DIR/bitcoin.csv" "btc_volume"
convert "$HOME/hpdic/Hermes/experiments/dataset/covid19" "$TMP_DIR/covid19.csv" "covid_metric"
convert "$HOME/hpdic/Hermes/experiments/dataset/hg38" "$TMP_DIR/hg38.csv" "gene_metric"

echo "[✓] CSV files created under $TMP_DIR/"
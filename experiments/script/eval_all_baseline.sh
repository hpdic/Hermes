#!/bin/bash

# ==============================================================================
# @file eval_all_baseline.sh
# @author Dongfang Zhao (dzhao@uw.edu)
#
# @brief Automated orchestration script for executing all baseline evaluations.
#
# @details
# This top level wrapper script sequentially triggers the singular baseline 
# evaluation process across the three primary experimental datasets: Bitcoin 
# transactions, COVID19 statistics, and Human Genome hg38 metrics. It ensures 
# a consistent and reproducible testing environment by applying the exact same 
# baseline cryptographic operations to each table in succession. The generated 
# performance metrics serve as the unoptimized reference point against which 
# the Hermes packed SIMD operations are compared.
#
# @dependencies
# * eval_baseline.sh : The core singular evaluation script located in the 
#   ./experiments/script/ directory.
# * MySQL Server : Configured and running with the hermes_apps database.
#
# @usage
# bash eval_all_baseline.sh
# ==============================================================================

set -e

TABLES=('tbl_bitcoin' 'tbl_covid19' 'tbl_hg38')

echo '[*] Starting baseline evaluations...'

for table in ${TABLES[@]}; do
  echo '    [+] Executing: ./experiments/script/eval_baseline.sh -t '$table
  bash ./experiments/script/eval_baseline.sh -t $table
done

echo '[*] Baselines completed.'
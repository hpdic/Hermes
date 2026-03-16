#!/bin/bash
set -e

TABLES=('tbl_bitcoin' 'tbl_covid19' 'tbl_hg38')

echo '[*] Starting baseline evaluations...'

for table in ${TABLES[@]}; do
  echo '    [+] Executing: ./experiments/script/eval_baseline.sh -t '$table
  bash ./experiments/script/eval_baseline.sh -t $table
done

echo '[*] Baselines completed.'
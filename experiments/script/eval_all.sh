#!/bin/bash
set -e

TABLES=('tbl_bitcoin' 'tbl_covid19' 'tbl_hg38')
SCALES=(128 256 512 1024 2048 4096)
SCRIPTS=('./experiments/script/eval_encrypt.sh' './experiments/script/eval_insert.sh' './experiments/script/eval_remove.sh')

echo '[*] Starting full evaluation sweep...'

### 1. Run Baselines Once
echo '[*] Running independent baselines...'
for table in ${TABLES[@]}; do
  echo '    [+] Executing: ./experiments/script/eval_baseline.sh -t '$table
  bash ./experiments/script/eval_baseline.sh -t $table
done

### 2. Run Packed Evaluations
for size in ${SCALES[@]}; do
  echo '[*] Processing pack size: '$size
  for table in ${TABLES[@]}; do
    echo '    [*] Target table: '$table
    for script in ${SCRIPTS[@]}; do
      echo '        [+] Executing: '$script' -t '$table' -p '$size
      bash $script -t $table -p $size
    done
  done
done

echo '[*] All sweeps completed successfully.'

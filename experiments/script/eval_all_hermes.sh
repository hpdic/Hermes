#!/bin/bash

# ==============================================================================
# @file eval_all_hermes.sh
# @author Dongfang Zhao (dzhao@uw.edu)
#
# @brief Automated orchestration script for the comprehensive Hermes evaluation sweep.
#
# @details
# This master script systematically benchmarks the performance of the Hermes 
# packed SIMD operations across a spectrum of vector scales ranging from 128 to 
# 4096 slots. For every combination of dataset and pack size, it dynamically 
# recalculates and updates the group_id column in the MySQL database. This 
# ensures the data rows are perfectly aligned into exact batches before invoking 
# the core cryptographic tests. It sequentially triggers the encryption, insertion, 
# and deletion evaluation scripts to generate the complete set of experimental 
# results required to demonstrate the scalability of the Hermes architecture.
#
# @dependencies
# * eval_encrypt.sh : Benchmarks group level packed encryption throughput.
# * eval_insert.sh : Benchmarks packed in place slot insertion speed.
# * eval_remove.sh : Benchmarks packed in place slot deletion speed.
# * MySQL Server : Must be actively running with the hermes_apps database.
#
# @usage
# bash eval_all_hermes.sh
# ==============================================================================

set -e

export MYSQL_PWD='hpdic2023'
MYSQL_USER='hpdic'
MYSQL_DB='hermes_apps'

TABLES=('tbl_bitcoin' 'tbl_covid19' 'tbl_hg38')
SCALES=(128 256 512 1024 2048 4096)
SCRIPTS=('./experiments/script/eval_encrypt.sh' './experiments/script/eval_insert.sh' './experiments/script/eval_remove.sh')

echo '[*] Starting Hermes packed evaluation sweep...'

for size in ${SCALES[@]}; do
  echo '[*] Processing pack size: '$size
  for table in ${TABLES[@]}; do
    echo '    [*] Target table: '$table
    echo '    [*] Dynamically updating group_id for pack size: '$size
    
    mysql -u $MYSQL_USER -D $MYSQL_DB -e 'UPDATE '$table' JOIN (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM '$table') AS tmp ON '$table'.id = tmp.id SET '$table'.group_id = FLOOR((tmp.rn - 1) / '$size') + 1;'

    for script in ${SCRIPTS[@]}; do
      echo '        [+] Executing: '$script' -t '$table' -p '$size
      bash $script -t $table -p $size
    done
  done
done

echo '[*] Hermes sweep completed successfully.'
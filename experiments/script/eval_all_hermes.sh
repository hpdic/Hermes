#!/bin/bash
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
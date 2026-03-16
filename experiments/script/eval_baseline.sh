#!/bin/bash

# ==============================================================================
# @file eval_baseline.sh
# @author Dongfang Zhao (dzhao@uw.edu)
#
# @brief Measures baseline performance for singular FHE and plaintext operations.
#
# @details
# This script establishes the baseline performance metrics by executing
# traditional scalar homomorphic encryption operations alongside standard
# plaintext database queries. It creates temporary tables to isolate
# the testing environment and evaluates three primary database workloads:
# bulk encryption, record insertion, and record deletion. The results
# serve as the unoptimized comparative foundation for evaluating the
# throughput improvements of the Hermes SIMD packed architecture.
#
# @parameters
# * table : Specifies the target database table for baseline testing.
#           Defaults to tbl_bitcoin.
#
# @dependencies
# * MySQL Server : Configured with the hermes_apps database.
# * HERMES_ENC_SINGULAR : The registered UDF for scalar encryption.
#
# @usage
# bash eval_baseline.sh --table tbl_bitcoin
# ==============================================================================

set -e

export MYSQL_PWD='hpdic2023'
MYSQL_USER='hpdic'
MYSQL_DB='hermes_apps'

TABLE='tbl_bitcoin'

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--table)
      TABLE=$2
      shift 2
      ;;
    -h|--help)
      echo 'Usage: '$0' [-t table_name]'
      exit 0
      ;;
    *)
      echo 'Unknown argument: '$1
      exit 1
      ;;
  esac
done

PREFIX=${TABLE#tbl_}
SINGULAR_TABLE='tbl_'$PREFIX'_singular'
PLAIN_TABLE='tbl_'$PREFIX'_plain'

OUT_DIR='./experiments/result/baseline'
OUT_FILE=$OUT_DIR'/'$PREFIX'.txt'

mkdir -p $OUT_DIR
echo '[*] Running baseline experiment on table: '$TABLE | tee $OUT_FILE

total_rows=$(mysql -u $MYSQL_USER -D $MYSQL_DB -sN -e 'SELECT COUNT(*) FROM '$TABLE';')
echo '[*] Total rows: '$total_rows | tee -a $OUT_FILE

### 1. Singular Encrypt Baseline
echo '[*] Timing HERMES_ENC_SINGULAR (bulk SELECT)...' | tee -a $OUT_FILE
start_sing_enc=$(date +%s%3N)
if [[ $PREFIX == 'bitcoin' ]]; then
  mysql -u $MYSQL_USER -D $MYSQL_DB -e 'SELECT HERMES_ENC_SINGULAR(FLOOR(value / 24)) FROM '$TABLE';' > /dev/null
else
  mysql -u $MYSQL_USER -D $MYSQL_DB -e 'SELECT HERMES_ENC_SINGULAR(value) FROM '$TABLE';' > /dev/null
fi
end_sing_enc=$(date +%s%3N)
elapsed_sing_enc=$((end_sing_enc - start_sing_enc))
echo 'SINGULAR-ENCRYPT: total='$elapsed_sing_enc' ms' | tee -a $OUT_FILE

### 2. Prepare Temp Tables for Insert/Remove
mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
DROP TABLE IF EXISTS $SINGULAR_TABLE;
CREATE TABLE $SINGULAR_TABLE (id INT PRIMARY KEY AUTO_INCREMENT, value INT, ctxt_repr LONGTEXT);
DROP TABLE IF EXISTS $PLAIN_TABLE;
CREATE TABLE $PLAIN_TABLE (id INT PRIMARY KEY AUTO_INCREMENT, value INT);
EOF

echo '[*] Loading group_id = 1 data into temp tables...' | tee -a $OUT_FILE
if [[ $PREFIX == 'bitcoin' ]]; then
  mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
  INSERT INTO $SINGULAR_TABLE(value, ctxt_repr) SELECT CAST(ROUND(value / 24) AS UNSIGNED), HERMES_ENC_SINGULAR(CAST(ROUND(value / 24) AS UNSIGNED)) FROM $TABLE WHERE group_id = 1;
  INSERT INTO $PLAIN_TABLE(value) SELECT CAST(ROUND(value / 24) AS UNSIGNED) FROM $TABLE WHERE group_id = 1;
EOF
else
  mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
  INSERT INTO $SINGULAR_TABLE(value, ctxt_repr) SELECT value, HERMES_ENC_SINGULAR(value) FROM $TABLE WHERE group_id = 1;
  INSERT INTO $PLAIN_TABLE(value) SELECT value FROM $TABLE WHERE group_id = 1;
EOF
fi

### 3. Singular and Plain Insert Baseline
TMP_SING_INS='tmp_sing_ins.sql'
TMP_PLAIN_INS='tmp_plain_ins.sql'
rm -f $TMP_SING_INS $TMP_PLAIN_INS

for ((i = 0; i < 100; i++)); do
  val=$((10 + RANDOM % 990))
  echo 'INSERT INTO '$SINGULAR_TABLE'(value, ctxt_repr) VALUES ('$val', HERMES_ENC_SINGULAR('$val'));' >> $TMP_SING_INS
  echo 'INSERT INTO '$PLAIN_TABLE'(value) VALUES ('$val');' >> $TMP_PLAIN_INS
done

start_sing_ins=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_SING_INS > /dev/null
end_sing_ins=$(date +%s%3N)
elapsed_sing_ins=$((end_sing_ins - start_sing_ins))

start_plain_ins=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PLAIN_INS > /dev/null
end_plain_ins=$(date +%s%3N)
elapsed_plain_ins=$((end_plain_ins - start_plain_ins))

### 4. Singular and Plain Remove Baseline
TMP_SING_RMV='tmp_sing_rmv.sql'
TMP_PLAIN_RMV='tmp_plain_rmv.sql'
rm -f $TMP_SING_RMV $TMP_PLAIN_RMV

ids_to_delete_sing=$(mysql -u $MYSQL_USER -D $MYSQL_DB -sN -e 'SELECT id FROM '$SINGULAR_TABLE' ORDER BY id ASC LIMIT 100;')
for id in $ids_to_delete_sing; do
  echo 'DELETE FROM '$SINGULAR_TABLE' WHERE id = '$id';' >> $TMP_SING_RMV
done

ids_to_delete_plain=$(mysql -u $MYSQL_USER -D $MYSQL_DB -sN -e 'SELECT id FROM '$PLAIN_TABLE' ORDER BY id ASC LIMIT 100;')
for id in $ids_to_delete_plain; do
  echo 'DELETE FROM '$PLAIN_TABLE' WHERE id = '$id';' >> $TMP_PLAIN_RMV
done

start_sing_rmv=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_SING_RMV > /dev/null
end_sing_rmv=$(date +%s%3N)
elapsed_sing_rmv=$((end_sing_rmv - start_sing_rmv))

start_plain_rmv=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PLAIN_RMV > /dev/null
end_plain_rmv=$(date +%s%3N)
elapsed_plain_rmv=$((end_plain_rmv - start_plain_rmv))

### Summary
rm -f $TMP_SING_INS $TMP_PLAIN_INS $TMP_SING_RMV $TMP_PLAIN_RMV

echo '' | tee -a $OUT_FILE
echo '------ Baseline Summary ('$TABLE') ------' | tee -a $OUT_FILE
echo 'Singular Encrypt: '$elapsed_sing_enc' ms' | tee -a $OUT_FILE
echo 'Singular Insert:  '$elapsed_sing_ins' ms' | tee -a $OUT_FILE
echo 'Plaintext Insert: '$elapsed_plain_ins' ms' | tee -a $OUT_FILE
echo 'Singular Remove:  '$elapsed_sing_rmv' ms' | tee -a $OUT_FILE
echo 'Plaintext Remove: '$elapsed_plain_rmv' ms' | tee -a $OUT_FILE

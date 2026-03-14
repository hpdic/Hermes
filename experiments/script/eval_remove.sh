#!/bin/bash
set -e

export MYSQL_PWD='hpdic2023'
MYSQL_USER='hpdic'
MYSQL_DB='hermes_apps'

TABLE='tbl_bitcoin'
SIZE_PACK=128

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--table)
      TABLE=$2
      shift 2
      ;;
    -p|--pack)
      SIZE_PACK=$2
      shift 2
      ;;
    -h|--help)
      echo 'Usage: '$0' [-t table_name] [-p pack_size]'
      exit 0
      ;;
    *)
      echo 'Unknown argument: '$1
      exit 1
      ;;
  esac
done

PREFIX=${TABLE#tbl_}
PACK_TABLE='tbl_'$PREFIX'_pack'
SINGULAR_TABLE='tbl_'$PREFIX'_singular'
PLAIN_TABLE='tbl_'$PREFIX'_plain'

OUT_DIR='./experiments/result/scale_'$SIZE_PACK
OUT_FILE=$OUT_DIR'/remove_'$PREFIX'.txt'

mkdir -p $OUT_DIR
echo '[*] Remove experiment on table: '$TABLE | tee $OUT_FILE

#######################################
# Step 1: Assume temporary tables already exist from previous insert test
#######################################

#######################################
# Step 2: Generate 100 deletes
#######################################
echo '[*] Generating 100 deletes...' | tee -a $OUT_FILE

slot_count=$(mysql -N -u $MYSQL_USER -D $MYSQL_DB -e 'SELECT slot_count FROM '$PACK_TABLE' WHERE group_id = 1 LIMIT 1;')

if (( slot_count <= 1 )); then
  echo '[!] Not enough slots to perform deletion.' | tee -a $OUT_FILE
  exit 1
fi

TMP_PACK='tmp_pack_remove.sql'
TMP_SING='tmp_sing_remove.sql'
TMP_PLAIN='tmp_plain_remove.sql'

rm -f $TMP_PACK $TMP_SING $TMP_PLAIN

k=$slot_count  
for ((i = 0; i < 100; i++)); do
  slot=$((RANDOM % (slot_count - 2)))
  echo 'SELECT HERMES_PACK_RMV(ctxt_repr, '$slot', '$k') FROM '$PACK_TABLE' WHERE group_id = 1;' >> $TMP_PACK
  ((k--))  
done

ids_to_delete=$(mysql -u $MYSQL_USER -D $MYSQL_DB -sN -e 'SELECT id FROM '$SINGULAR_TABLE' ORDER BY id ASC LIMIT 100;')
for id in $ids_to_delete; do
  echo 'DELETE FROM '$SINGULAR_TABLE' WHERE id = '$id';' >> $TMP_SING
done

ids_to_delete_plain=$(mysql -u $MYSQL_USER -D $MYSQL_DB -sN -e 'SELECT id FROM '$PLAIN_TABLE' ORDER BY id ASC LIMIT 100;')
for id in $ids_to_delete_plain; do
  echo 'DELETE FROM '$PLAIN_TABLE' WHERE id = '$id';' >> $TMP_PLAIN
done

#######################################
# Step 3: Time PACK REMOVE
#######################################
echo '[*] Running PACK removes...' | tee -a $OUT_FILE
start_pack=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PACK > /dev/null
end_pack=$(date +%s%3N)
elapsed_pack=$((end_pack - start_pack))
echo 'PACK-REMOVE: total='$elapsed_pack' ms' | tee -a $OUT_FILE

mysql -u $MYSQL_USER -D $MYSQL_DB -e 'UPDATE '$PACK_TABLE' SET slot_count = slot_count - 100 WHERE group_id = 1;'

#######################################
# Step 4: Time SINGULAR DELETE
#######################################
echo '[*] Running SINGULAR deletes...' | tee -a $OUT_FILE
start_sing=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_SING > /dev/null
end_sing=$(date +%s%3N)
elapsed_sing=$((end_sing - start_sing))
echo 'SINGULAR-REMOVE: total='$elapsed_sing' ms' | tee -a $OUT_FILE

#######################################
# Step 5: Time PLAIN DELETE
#######################################
echo '[*] Running PLAIN deletes...' | tee -a $OUT_FILE
start_plain=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PLAIN > /dev/null
end_plain=$(date +%s%3N)
elapsed_plain=$((end_plain - start_plain))
echo 'PLAIN-REMOVE: total='$elapsed_plain' ms' | tee -a $OUT_FILE

#######################################
# Summary
#######################################
rm -f $TMP_PACK $TMP_SING $TMP_PLAIN

echo '' | tee -a $OUT_FILE
echo '------ Summary (remove eval on '$TABLE', group_id=1) ------' | tee -a $OUT_FILE
echo 'Timestamp: '$(date '+%Y-%m-%d %H:%M:%S') | tee -a $OUT_FILE
echo 'Host: '$(hostname) | tee -a $OUT_FILE
echo 'Kernel: '$(uname -r) | tee -a $OUT_FILE
echo 'Packed Remove:    '$elapsed_pack' ms (avg: '$((elapsed_pack * 10))' us/op)' | tee -a $OUT_FILE
echo 'Singular Remove:  '$elapsed_sing' ms (avg: '$((elapsed_sing * 10))' us/op)' | tee -a $OUT_FILE
echo 'Plaintext Remove: '$elapsed_plain' ms (avg: '$((elapsed_plain * 10))' us/op)' | tee -a $OUT_FILE

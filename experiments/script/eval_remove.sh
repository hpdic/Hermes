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

OUT_DIR='./experiments/result/scale_'$SIZE_PACK
OUT_FILE=$OUT_DIR'/remove_'$PREFIX'.txt'

mkdir -p $OUT_DIR
echo '[*] Packed remove experiment on table: '$TABLE | tee $OUT_FILE

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
rm -f $TMP_PACK

k=$slot_count  
for ((i = 0; i < 100; i++)); do
  slot=$((RANDOM % (slot_count - 2)))
  echo 'SELECT HERMES_PACK_RMV(ctxt_repr, '$slot', '$k') FROM '$PACK_TABLE' WHERE group_id = 1;' >> $TMP_PACK
  ((k--))  
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
# Summary
#######################################
rm -f $TMP_PACK

echo '' | tee -a $OUT_FILE
echo '------ Summary (packed remove on '$TABLE', group_id=1) ------' | tee -a $OUT_FILE
echo 'Timestamp: '$(date '+%Y-%m-%d %H:%M:%S') | tee -a $OUT_FILE
echo 'Host: '$(hostname) | tee -a $OUT_FILE
echo 'Kernel: '$(uname -r) | tee -a $OUT_FILE
echo 'Packed Remove: '$elapsed_pack' ms (avg: '$((elapsed_pack * 10))' us/op)' | tee -a $OUT_FILE

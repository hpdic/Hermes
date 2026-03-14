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
OUT_FILE=$OUT_DIR'/insert_'$PREFIX'.txt'

mkdir -p $OUT_DIR
echo '[*] Insert experiment on table: '$TABLE | tee $OUT_FILE

#######################################
# Step 1: Create temporary tables
#######################################
mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
DROP TABLE IF EXISTS $PACK_TABLE;
CREATE TABLE $PACK_TABLE (
  id INT PRIMARY KEY AUTO_INCREMENT,
  group_id INT,
  slot_count INT,
  ctxt_repr LONGTEXT
);

DROP TABLE IF EXISTS $SINGULAR_TABLE;
CREATE TABLE $SINGULAR_TABLE (
  id INT PRIMARY KEY AUTO_INCREMENT,
  value INT,
  ctxt_repr LONGTEXT
);

DROP TABLE IF EXISTS $PLAIN_TABLE;
CREATE TABLE $PLAIN_TABLE (
  id INT PRIMARY KEY AUTO_INCREMENT,
  value INT
);
EOF

#######################################
# Step 2: Load group_id = 1 data
#######################################
echo '[*] Loading group_id = 1 data into temp tables...' | tee -a $OUT_FILE

if [[ $PREFIX == 'bitcoin' ]]; then
  mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
  INSERT INTO $SINGULAR_TABLE(value, ctxt_repr)
  SELECT CAST(ROUND(value / 24) AS UNSIGNED), HERMES_ENC_SINGULAR(CAST(ROUND(value / 24) AS UNSIGNED))
  FROM $TABLE WHERE group_id = 1;

  INSERT INTO $PACK_TABLE(group_id, slot_count, ctxt_repr)
  SELECT 1, count(*), HERMES_PACK_CONVERT(CAST(ROUND(value / 24) AS UNSIGNED))
  FROM $TABLE WHERE group_id = 1;

  INSERT INTO $PLAIN_TABLE(value)
  SELECT CAST(ROUND(value / 24) AS UNSIGNED)
  FROM $TABLE WHERE group_id = 1;
EOF
else
  mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
  INSERT INTO $SINGULAR_TABLE(value, ctxt_repr)
  SELECT value, HERMES_ENC_SINGULAR(value)
  FROM $TABLE WHERE group_id = 1;

  INSERT INTO $PACK_TABLE(group_id, slot_count, ctxt_repr)
  SELECT 1, count(*), HERMES_PACK_CONVERT(value)
  FROM $TABLE WHERE group_id = 1;

  INSERT INTO $PLAIN_TABLE(value)
  SELECT value
  FROM $TABLE WHERE group_id = 1;
EOF
fi

#######################################
# Step 3: Generate 100 inserts via Temp Files
#######################################
echo '[*] Generating 100 inserts...' | tee -a $OUT_FILE

slot_count=$(mysql -N -B -u $MYSQL_USER -D $MYSQL_DB -e 'SELECT slot_count FROM '$PACK_TABLE' WHERE group_id = 1 LIMIT 1;')

if [[ -z $slot_count ]]; then
  echo 'Error: slot_count not found for group_id = 1'
  exit 1
fi

TMP_PACK='tmp_pack_insert.sql'
TMP_SING='tmp_sing_insert.sql'
TMP_PLAIN='tmp_plain_insert.sql'

rm -f $TMP_PACK $TMP_SING $TMP_PLAIN

for ((i = 0; i < 100; i++)); do
  val=$((10 + RANDOM % 990))
  slot=$((slot_count + i))
  
  echo 'SELECT HERMES_PACK_ADD(ctxt_repr, '$slot', '$val') FROM '$PACK_TABLE' WHERE group_id = 1;' >> $TMP_PACK
  echo 'INSERT INTO '$SINGULAR_TABLE'(value, ctxt_repr) VALUES ('$val', HERMES_ENC_SINGULAR('$val'));' >> $TMP_SING
  echo 'INSERT INTO '$PLAIN_TABLE'(value) VALUES ('$val');' >> $TMP_PLAIN
done

#######################################
# Step 4: Time PACK INSERT
#######################################
echo '[*] Running PACK inserts...' | tee -a $OUT_FILE
start_pack=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PACK > /dev/null
end_pack=$(date +%s%3N)
elapsed_pack=$((end_pack - start_pack))
echo 'PACK-INSERT: total='$elapsed_pack' ms' | tee -a $OUT_FILE

new_slot_count=$((slot_count + 100))
mysql -u $MYSQL_USER -D $MYSQL_DB -e 'UPDATE '$PACK_TABLE' SET slot_count = '$new_slot_count' WHERE group_id = 1;'

#######################################
# Step 5: Time SINGULAR INSERT
#######################################
echo '[*] Running SINGULAR inserts...' | tee -a $OUT_FILE
start_sing=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_SING > /dev/null
end_sing=$(date +%s%3N)
elapsed_sing=$((end_sing - start_sing))
echo 'SINGULAR-INSERT: total='$elapsed_sing' ms' | tee -a $OUT_FILE

#######################################
# Step 6: Time PLAIN INSERT
#######################################
echo '[*] Running PLAIN inserts...' | tee -a $OUT_FILE
start_plain=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PLAIN > /dev/null
end_plain=$(date +%s%3N)
elapsed_plain=$((end_plain - start_plain))
echo 'PLAIN-INSERT: total='$elapsed_plain' ms' | tee -a $OUT_FILE

#######################################
# Summary
#######################################
rm -f $TMP_PACK $TMP_SING $TMP_PLAIN

echo '' | tee -a $OUT_FILE
echo '------ Summary (insert eval on '$TABLE', group_id=1) ------' | tee -a $OUT_FILE
echo 'Timestamp: '$(date '+%Y-%m-%d %H:%M:%S') | tee -a $OUT_FILE
echo 'Host: '$(hostname) | tee -a $OUT_FILE
echo 'Kernel: '$(uname -r) | tee -a $OUT_FILE
echo 'Packed Insert:    '$elapsed_pack' ms (avg: '$((elapsed_pack * 10))' us/op)' | tee -a $OUT_FILE
echo 'Singular Insert:  '$elapsed_sing' ms (avg: '$((elapsed_sing * 10))' us/op)' | tee -a $OUT_FILE
echo 'Plaintext Insert: '$elapsed_plain' ms (avg: '$((elapsed_plain * 10))' us/op)' | tee -a $OUT_FILE

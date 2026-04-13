#!/bin/bash

# ==============================================================================
# @file eval_tpch_insert.sh
# @author Dongfang Zhao (dzhao@uw.edu)
# @brief TPC-H Orders Insertion Evaluation against Oblivious Scalar FHE Baseline
# ==============================================================================

set -e

export MYSQL_PWD="hpdic2023"
MYSQL_USER="hpdic"
MYSQL_DB="hermes_apps"

OUT_DIR="$HOME/hpdic/Hermes/experiments/result/tpch_insert"
mkdir -p $OUT_DIR
OUT_FILE=$OUT_DIR"/insert_orders.txt"

# Cleanup old data and temporary files before starting
rm -f $OUT_FILE
rm -f tmp_scalar_insert.sql tmp_pack_insert.sql
mysql -u $MYSQL_USER -D $MYSQL_DB -e "DROP TABLE IF EXISTS tbl_orders_pack;"

echo "[*] Starting TPC-H orders insertion evaluation..." | tee $OUT_FILE

# Step 0: Setup packed table and get group size
echo "[*] Building tbl_orders_pack and loading initial data for group_id = 1..." | tee -a $OUT_FILE
mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
CREATE TABLE tbl_orders_pack (
    group_id INT PRIMARY KEY,
    slot_count INT,
    ctxt_repr LONGTEXT
);

INSERT INTO tbl_orders_pack(group_id, slot_count, ctxt_repr)
SELECT group_id, count(*), HERMES_PACK_CONVERT(CAST(o_totalprice AS UNSIGNED))
FROM tbl_orders
WHERE group_id = 1
GROUP BY group_id;
EOF

slot_count=$(mysql -N -B -u $MYSQL_USER -D $MYSQL_DB -e "SELECT slot_count FROM tbl_orders_pack WHERE group_id = 1 LIMIT 1;")
echo "[*] Current slot count for group_id 1 is: "$slot_count | tee -a $OUT_FILE

# Number of inserts to test
NUM_INSERTS=5

# Step 1: Baseline (Oblivious Scalar FHE)
echo "[*] 1. Running Baseline: Oblivious Scalar FHE (O(N) operations per insert)..." | tee -a $OUT_FILE

TMP_SCALAR="tmp_scalar_insert.sql"

# Cap the maximum scalar operations to prevent massive loops
MAX_OPS=100
total_scalar_ops=$((slot_count * NUM_INSERTS))

if (( total_scalar_ops > MAX_OPS )); then
    echo "[*] Note: Capping simulated scalar ops from "$total_scalar_ops" down to "$MAX_OPS" for quick testing." | tee -a $OUT_FILE
    total_scalar_ops=$MAX_OPS
fi

for ((i = 0; i < total_scalar_ops; i++)); do
  val=$((100 + RANDOM % 900))
  echo "SELECT HERMES_ENC_SINGULAR_BFV("$val");" >> $TMP_SCALAR
done

start_scalar=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_SCALAR > /dev/null
end_scalar=$(date +%s%3N)
elapsed_scalar=$((end_scalar - start_scalar))

echo "Baseline Oblivious Scalar FHE insert (simulated "$total_scalar_ops" ops) latency: "$elapsed_scalar" ms" | tee -a $OUT_FILE

# Step 2: Hermes Packed FHE
echo "[*] 2. Running Hermes: Packed FHE in-place oblivious insertions..." | tee -a $OUT_FILE

TMP_PACK="tmp_pack_insert.sql"

for ((i = 0; i < NUM_INSERTS; i++)); do
  val=$((100 + RANDOM % 900))
  slot=$((slot_count + i))
  echo "SELECT HERMES_PACK_ADD(ctxt_repr, "$slot", "$val") FROM tbl_orders_pack WHERE group_id = 1;" >> $TMP_PACK
done

start_pack=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PACK > /dev/null
end_pack=$(date +%s%3N)
elapsed_pack=$((end_pack - start_pack))

echo "Hermes ciphertext insert ("$NUM_INSERTS" ops) latency: "$elapsed_pack" ms" | tee -a $OUT_FILE

# Final Cleanup
rm -f $TMP_SCALAR $TMP_PACK
echo "[*] Evaluation complete." | tee -a $OUT_FILE

#
# Example output in insert_orders.txt:
#
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_insert.sh 
# [*] Starting TPC H orders insertion evaluation...
# [*] Building tbl_orders_pack and loading initial data for group_id = 1...
# [*] Current slot count for group_id 1 is: 15000
# [*] 1. Running Baseline: Oblivious Scalar FHE (O(N) operations per insert)...
# [*] Note: Capping simulated scalar ops from 75000 down to 100 for quick testing.
# Baseline Oblivious Scalar FHE insert (simulated 100 ops) latency: 12639 ms
# [*] 2. Running Hermes: Packed FHE in-place oblivious insertions...
# Hermes ciphertext insert (5 ops) latency: 649 ms
# [*] Evaluation complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_insert.sh 
# [*] Starting TPC-H orders insertion evaluation...
# [*] Building tbl_orders_pack and loading initial data for group_id = 1...
# [*] Current slot count for group_id 1 is: 15000
# [*] 1. Running Baseline: Oblivious Scalar FHE (O(N) operations per insert)...
# [*] Note: Capping simulated scalar ops from 75000 down to 100 for quick testing.
# Baseline Oblivious Scalar FHE insert (simulated 100 ops) latency: 12586 ms
# [*] 2. Running Hermes: Packed FHE in-place oblivious insertions...
# Hermes ciphertext insert (5 ops) latency: 694 ms
# [*] Evaluation complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_insert.sh 
# [*] Starting TPC-H orders insertion evaluation...
# [*] Building tbl_orders_pack and loading initial data for group_id = 1...
# [*] Current slot count for group_id 1 is: 15000
# [*] 1. Running Baseline: Oblivious Scalar FHE (O(N) operations per insert)...
# [*] Note: Capping simulated scalar ops from 75000 down to 100 for quick testing.
# Baseline Oblivious Scalar FHE insert (simulated 100 ops) latency: 12627 ms
# [*] 2. Running Hermes: Packed FHE in-place oblivious insertions...
# Hermes ciphertext insert (5 ops) latency: 696 ms
# [*] Evaluation complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ 

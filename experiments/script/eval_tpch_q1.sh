#!/bin/bash

# ==============================================================================
# @file eval_tpch_q1.sh
# @author Dongfang Zhao (dzhao@uw.edu)
# @brief TPC-H Q1 Simplified Single-Column Aggregation Evaluation
# ==============================================================================

set -e

export MYSQL_PWD='hpdic2023'
MYSQL_USER='hpdic'
MYSQL_DB='hermes_apps'

OUT_DIR="$HOME/hpdic/Hermes/experiments/result/tpch_q1"
mkdir -p $OUT_DIR
OUT_FILE=$OUT_DIR'/q1_sum.txt'

echo '[*] Starting TPC H Q1 aggregation evaluation...' | tee $OUT_FILE

# Step 1: Prepare the packed ciphertext table
echo '[*] Building tbl_lineitem_pack and injecting ciphertext data...' | tee -a $OUT_FILE
mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
DROP TABLE IF EXISTS tbl_lineitem_pack;
CREATE TABLE tbl_lineitem_pack (
    group_id INT PRIMARY KEY,
    slot_count INT,
    ctxt_repr LONGTEXT
);

-- Pack data from the same group into a single ciphertext
-- Casting l_quantity to UNSIGNED integer to satisfy HERMES_PACK_CONVERT type requirement
INSERT INTO tbl_lineitem_pack(group_id, slot_count, ctxt_repr)
SELECT group_id, count(*), HERMES_PACK_CONVERT(CAST(l_quantity AS UNSIGNED))
FROM tbl_lineitem
GROUP BY group_id;
EOF

# Step 2: Test native plaintext aggregation
echo '[*] Running native plaintext aggregation...' | tee -a $OUT_FILE
start_plain=$(date +%s%3N)
mysql -u $MYSQL_USER -D $MYSQL_DB -e 'SELECT SUM(l_quantity) FROM tbl_lineitem;' > /dev/null
end_plain=$(date +%s%3N)
elapsed_plain=$((end_plain - start_plain))
echo 'Plaintext aggregation latency: '$elapsed_plain' ms' | tee -a $OUT_FILE

# Step 3: Test Hermes ciphertext aggregation
echo '[*] Running Hermes ciphertext aggregation...' | tee -a $OUT_FILE
start_hermes=$(date +%s%3N)

# Using HERMES_PACK_GLOBAL_SUM to aggregate all group ciphertexts
mysql -u $MYSQL_USER -D $MYSQL_DB -e 'SELECT HERMES_PACK_GLOBAL_SUM(ctxt_repr) FROM tbl_lineitem_pack;' > /dev/null

end_hermes=$(date +%s%3N)
elapsed_hermes=$((end_hermes - start_hermes))
echo 'Hermes ciphertext aggregation latency: '$elapsed_hermes' ms' | tee -a $OUT_FILE

echo '[*] Evaluation complete.' | tee -a $OUT_FILE

#
# Example output in q1_sum.txt:
#
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_q1.sh 
# [*] Starting TPC H Q1 aggregation evaluation...
# [*] Building tbl_lineitem_pack and injecting ciphertext data...
# [*] Running native plaintext aggregation...
# Plaintext aggregation latency: 125 ms
# [*] Running Hermes ciphertext aggregation...
# Hermes ciphertext aggregation latency: 97 ms
# [*] Evaluation complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_q1.sh 
# [*] Starting TPC H Q1 aggregation evaluation...
# [*] Building tbl_lineitem_pack and injecting ciphertext data...
# [*] Running native plaintext aggregation...
# Plaintext aggregation latency: 129 ms
# [*] Running Hermes ciphertext aggregation...
# Hermes ciphertext aggregation latency: 97 ms
# [*] Evaluation complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_q1.sh 
# [*] Starting TPC H Q1 aggregation evaluation...
# [*] Building tbl_lineitem_pack and injecting ciphertext data...
# [*] Running native plaintext aggregation...
# Plaintext aggregation latency: 145 ms
# [*] Running Hermes ciphertext aggregation...
# Hermes ciphertext aggregation latency: 97 ms
# [*] Evaluation complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_q1.sh 
# [*] Starting TPC H Q1 aggregation evaluation...
# [*] Building tbl_lineitem_pack and injecting ciphertext data...
# [*] Running native plaintext aggregation...
# Plaintext aggregation latency: 124 ms
# [*] Running Hermes ciphertext aggregation...
# Hermes ciphertext aggregation latency: 97 ms
# [*] Evaluation complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ 

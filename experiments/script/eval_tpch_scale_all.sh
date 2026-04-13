#!/bin/bash

# ==============================================================================
# @file eval_tpch_scale_all.sh
# @author Dongfang Zhao (dzhao@uw.edu)
# @brief TPC-H Comprehensive Scalability Evaluation (Q1, Insert, Delete)
# ==============================================================================

set -e

export MYSQL_PWD="hpdic2023"
MYSQL_USER="hpdic"
MYSQL_DB="hermes_apps"

OUT_DIR="$HOME/hpdic/Hermes/experiments/result/tpch_scale"
mkdir -p $OUT_DIR
OUT_FILE=$OUT_DIR"/all_workloads_scale.txt"

rm -f $OUT_FILE
rm -f tmp_*.sql
mysql -u $MYSQL_USER -D $MYSQL_DB -e "DROP TABLE IF EXISTS tbl_lineitem_pack; DROP TABLE IF EXISTS tbl_orders_pack;"

echo "[*] Starting comprehensive scalability evaluation..." | tee $OUT_FILE

TUPLE_COUNTS=(1000 5000 10000 15000)
NUM_OPS=5
MAX_SCALAR_OPS=100

for TC in ${TUPLE_COUNTS[@]}; do
    echo "" | tee -a $OUT_FILE
    echo "[*] =========================================" | tee -a $OUT_FILE
    echo "[*] EVALUATING TUPLE COUNT: "$TC | tee -a $OUT_FILE
    echo "[*] =========================================" | tee -a $OUT_FILE

    # ---------------------------------------------------------
    # Workload 1: Q1 Aggregation
    # ---------------------------------------------------------
    echo "[*] --- Workload 1: Q1 Aggregation ---" | tee -a $OUT_FILE
    mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
    DROP TABLE IF EXISTS tbl_lineitem_pack;
    CREATE TABLE tbl_lineitem_pack (
        group_id INT PRIMARY KEY,
        slot_count INT,
        ctxt_repr LONGTEXT
    );
    INSERT INTO tbl_lineitem_pack(group_id, slot_count, ctxt_repr)
    SELECT 1, count(*), HERMES_PACK_CONVERT(CAST(l_quantity AS UNSIGNED))
    FROM (SELECT l_quantity FROM tbl_lineitem WHERE group_id = 1 LIMIT $TC) AS subq;
EOF

    start_plain=$(date +%s%3N)
    mysql -u $MYSQL_USER -D $MYSQL_DB -e "SELECT SUM(l_quantity) FROM (SELECT l_quantity FROM tbl_lineitem WHERE group_id = 1 LIMIT "$TC") AS subq;" > /dev/null
    end_plain=$(date +%s%3N)
    elapsed_plain=$((end_plain - start_plain))
    echo "Q1 Plaintext aggregation latency: "$elapsed_plain" ms" | tee -a $OUT_FILE

    start_hermes_q1=$(date +%s%3N)
    mysql -u $MYSQL_USER -D $MYSQL_DB -e "SELECT HERMES_PACK_GLOBAL_SUM(ctxt_repr) FROM tbl_lineitem_pack WHERE group_id = 1;" > /dev/null
    end_hermes_q1=$(date +%s%3N)
    elapsed_hermes_q1=$((end_hermes_q1 - start_hermes_q1))
    echo "Q1 Hermes aggregation latency: "$elapsed_hermes_q1" ms" | tee -a $OUT_FILE

    # ---------------------------------------------------------
    # Workload 2 & 3 Setup: Orders Table
    # ---------------------------------------------------------
    mysql -u $MYSQL_USER -D $MYSQL_DB <<EOF
    DROP TABLE IF EXISTS tbl_orders_pack;
    CREATE TABLE tbl_orders_pack (
        group_id INT PRIMARY KEY,
        slot_count INT,
        ctxt_repr LONGTEXT
    );
    INSERT INTO tbl_orders_pack(group_id, slot_count, ctxt_repr)
    SELECT 1, count(*), HERMES_PACK_CONVERT(CAST(o_totalprice AS UNSIGNED))
    FROM (SELECT o_totalprice FROM tbl_orders WHERE group_id = 1 LIMIT $TC) AS subq;
EOF
    slot_count=$(mysql -N -B -u $MYSQL_USER -D $MYSQL_DB -e "SELECT slot_count FROM tbl_orders_pack WHERE group_id = 1 LIMIT 1;")

    # ---------------------------------------------------------
    # Workload 2: Insertion
    # ---------------------------------------------------------
    echo "[*] --- Workload 2: Insertion ---" | tee -a $OUT_FILE
    TMP_SCALAR="tmp_scalar_insert.sql"
    rm -f $TMP_SCALAR
    total_scalar_ops=$((slot_count * NUM_OPS))
    if (( total_scalar_ops > MAX_SCALAR_OPS )); then
        total_scalar_ops=$MAX_SCALAR_OPS
    fi
    for ((i = 0; i < total_scalar_ops; i++)); do
        val=$((100 + RANDOM % 900))
        echo "SELECT HERMES_ENC_SINGULAR_BFV("$val");" >> $TMP_SCALAR
    done
    start_scalar_ins=$(date +%s%3N)
    mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_SCALAR > /dev/null
    end_scalar_ins=$(date +%s%3N)
    elapsed_scalar_ins=$((end_scalar_ins - start_scalar_ins))
    echo "Insert Baseline Scalar FHE (simulated "$total_scalar_ops" ops) latency: "$elapsed_scalar_ins" ms" | tee -a $OUT_FILE

    TMP_PACK_INS="tmp_pack_insert.sql"
    rm -f $TMP_PACK_INS
    for ((i = 0; i < NUM_OPS; i++)); do
        val=$((100 + RANDOM % 900))
        slot=$((slot_count + i))
        echo "SELECT HERMES_PACK_ADD(ctxt_repr, "$slot", "$val") FROM tbl_orders_pack WHERE group_id = 1;" >> $TMP_PACK_INS
    done
    start_pack_ins=$(date +%s%3N)
    mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PACK_INS > /dev/null
    end_pack_ins=$(date +%s%3N)
    elapsed_pack_ins=$((end_pack_ins - start_pack_ins))
    echo "Insert Hermes packed ("$NUM_OPS" ops) latency: "$elapsed_pack_ins" ms" | tee -a $OUT_FILE

    # ---------------------------------------------------------
    # Workload 3: Deletion
    # ---------------------------------------------------------
    echo "[*] --- Workload 3: Deletion ---" | tee -a $OUT_FILE
    TMP_SCALAR_DEL="tmp_scalar_delete.sql"
    rm -f $TMP_SCALAR_DEL
    for ((i = 0; i < total_scalar_ops; i++)); do
        val=$((100 + RANDOM % 900))
        echo "SELECT HERMES_ENC_SINGULAR_BFV("$val");" >> $TMP_SCALAR_DEL
    done
    start_scalar_del=$(date +%s%3N)
    mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_SCALAR_DEL > /dev/null
    end_scalar_del=$(date +%s%3N)
    elapsed_scalar_del=$((end_scalar_del - start_scalar_del))
    echo "Delete Baseline Scalar FHE (simulated "$total_scalar_ops" ops) latency: "$elapsed_scalar_del" ms" | tee -a $OUT_FILE

    TMP_PACK_DEL="tmp_pack_delete.sql"
    rm -f $TMP_PACK_DEL
    k=$slot_count
    for ((i = 0; i < NUM_OPS; i++)); do
        safe_bound=$((k - 2))
        if (( safe_bound < 1 )); then
            safe_bound=1
        fi
        slot=$((RANDOM % safe_bound))
        echo "SELECT HERMES_PACK_RMV(ctxt_repr, "$slot", "$k") FROM tbl_orders_pack WHERE group_id = 1;" >> $TMP_PACK_DEL
        ((k--))
    done
    start_pack_del=$(date +%s%3N)
    mysql -u $MYSQL_USER -D $MYSQL_DB < $TMP_PACK_DEL > /dev/null
    end_pack_del=$(date +%s%3N)
    elapsed_pack_del=$((end_pack_del - start_pack_del))
    echo "Delete Hermes packed ("$NUM_OPS" ops) latency: "$elapsed_pack_del" ms" | tee -a $OUT_FILE

done

rm -f tmp_*.sql
echo "" | tee -a $OUT_FILE
echo "[*] All scalability evaluations complete." | tee -a $OUT_FILE

#
# Example output:
#
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_scale_all.sh 
# [*] Starting comprehensive scalability evaluation...

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 1000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 21 ms
# Q1 Hermes aggregation latency: 45 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12628 ms
# Insert Hermes packed (5 ops) latency: 713 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12686 ms
# Delete Hermes packed (5 ops) latency: 329 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 5000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 33 ms
# Q1 Hermes aggregation latency: 42 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12760 ms
# Insert Hermes packed (5 ops) latency: 694 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12751 ms
# Delete Hermes packed (5 ops) latency: 373 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 10000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 50 ms
# Q1 Hermes aggregation latency: 42 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12581 ms
# Insert Hermes packed (5 ops) latency: 699 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12652 ms
# Delete Hermes packed (5 ops) latency: 91 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 15000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 79 ms
# Q1 Hermes aggregation latency: 42 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12751 ms
# Insert Hermes packed (5 ops) latency: 690 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12750 ms
# Delete Hermes packed (5 ops) latency: 89 ms

# [*] All scalability evaluations complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ 
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ 
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_scale_all.sh 
# [*] Starting comprehensive scalability evaluation...

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 1000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 19 ms
# Q1 Hermes aggregation latency: 41 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12605 ms
# Insert Hermes packed (5 ops) latency: 682 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12698 ms
# Delete Hermes packed (5 ops) latency: 348 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 5000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 31 ms
# Q1 Hermes aggregation latency: 41 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12630 ms
# Insert Hermes packed (5 ops) latency: 693 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12525 ms
# Delete Hermes packed (5 ops) latency: 381 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 10000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 49 ms
# Q1 Hermes aggregation latency: 42 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12754 ms
# Insert Hermes packed (5 ops) latency: 694 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12759 ms
# Delete Hermes packed (5 ops) latency: 63 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 15000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 78 ms
# Q1 Hermes aggregation latency: 43 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12658 ms
# Insert Hermes packed (5 ops) latency: 690 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12659 ms
# Delete Hermes packed (5 ops) latency: 90 ms

# [*] All scalability evaluations complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ 
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ 
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ ./script/eval_tpch_scale_all.sh 
# [*] Starting comprehensive scalability evaluation...

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 1000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 21 ms
# Q1 Hermes aggregation latency: 41 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12577 ms
# Insert Hermes packed (5 ops) latency: 697 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12645 ms
# Delete Hermes packed (5 ops) latency: 314 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 5000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 33 ms
# Q1 Hermes aggregation latency: 41 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12792 ms
# Insert Hermes packed (5 ops) latency: 686 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12735 ms
# Delete Hermes packed (5 ops) latency: 364 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 10000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 49 ms
# Q1 Hermes aggregation latency: 39 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12638 ms
# Insert Hermes packed (5 ops) latency: 666 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12621 ms
# Delete Hermes packed (5 ops) latency: 87 ms

# [*] =========================================
# [*] EVALUATING TUPLE COUNT: 15000
# [*] =========================================
# [*] --- Workload 1: Q1 Aggregation ---
# Q1 Plaintext aggregation latency: 82 ms
# Q1 Hermes aggregation latency: 43 ms
# [*] --- Workload 2: Insertion ---
# Insert Baseline Scalar FHE (simulated 100 ops) latency: 12815 ms
# Insert Hermes packed (5 ops) latency: 693 ms
# [*] --- Workload 3: Deletion ---
# Delete Baseline Scalar FHE (simulated 100 ops) latency: 12793 ms
# Delete Hermes packed (5 ops) latency: 79 ms

# [*] All scalability evaluations complete.
# (base) cc@uc-a100:~/hpdic/Hermes/experiments$ 

#!/bin/bash

# ==============================================================================
# @file load_tpch.sh
# @author Dongfang Zhao (dzhao@uw.edu)
# @brief Automated download, compilation, and import of TPC H tables into Hermes
# ==============================================================================

set -e

export MYSQL_PWD="hpdic2023"
MYSQL_USER="hpdic"
MYSQL_DB="hermes_apps"
MYSQL_CMD="mysql --local-infile=1 -u $MYSQL_USER"

# TPC H data scale factor (0.1 generates approx 100MB of data, suitable for quick testing)
SF=0.1

cd ~/hpdic
echo "[*] Fetching stable TPC H dbgen source code..."
if [ ! -d "tpch_dbgen" ]; then
    git clone https://github.com/hpdic/tpch-dbgen.git tpch_dbgen
fi

echo "[*] Compiling dbgen tool..."
cd tpch_dbgen
make

echo "[*] Generating orders and lineitem data (SF=$SF)..."
./dbgen -s $SF -T O
./dbgen -s $SF -T L
cd ..

echo "[*] Configuring database and import permissions..."
$MYSQL_CMD -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DB;"
$MYSQL_CMD -e "SET GLOBAL local_infile=1;" || echo "[!] Warning: Cannot set global local_infile. Please ensure it is enabled on the server."

echo "[*] Creating and importing tbl_orders..."
$MYSQL_CMD -D $MYSQL_DB <<EOF
DROP TABLE IF EXISTS tbl_orders;
CREATE TABLE tbl_orders (
    o_orderkey INT PRIMARY KEY,
    o_custkey INT,
    o_orderstatus CHAR(1),
    o_totalprice DECIMAL(15,2),
    o_orderdate DATE,
    o_orderpriority CHAR(15),
    o_clerk CHAR(15),
    o_shippriority INT,
    o_comment VARCHAR(79),
    group_id INT DEFAULT 1
);

LOAD DATA LOCAL INFILE 'tpch_dbgen/orders.tbl'
INTO TABLE tbl_orders
FIELDS TERMINATED BY '|'
LINES TERMINATED BY '|\n'
(o_orderkey, o_custkey, o_orderstatus, o_totalprice, o_orderdate, o_orderpriority, o_clerk, o_shippriority, o_comment);

-- Allocate group_id for Hermes encryption grouping
UPDATE tbl_orders SET group_id = (o_orderkey % 10) + 1;
EOF

echo "[*] Creating and importing tbl_lineitem..."
$MYSQL_CMD -D $MYSQL_DB <<EOF
DROP TABLE IF EXISTS tbl_lineitem;
CREATE TABLE tbl_lineitem (
    l_orderkey INT,
    l_partkey INT,
    l_suppkey INT,
    l_linenumber INT,
    l_quantity DECIMAL(15,2),
    l_extendedprice DECIMAL(15,2),
    l_discount DECIMAL(15,2),
    l_tax DECIMAL(15,2),
    l_returnflag CHAR(1),
    l_linestatus CHAR(1),
    l_shipdate DATE,
    l_commitdate DATE,
    l_receiptdate DATE,
    l_shipinstruct CHAR(25),
    l_shipmode CHAR(10),
    l_comment VARCHAR(44),
    group_id INT DEFAULT 1,
    PRIMARY KEY (l_orderkey, l_linenumber)
);

LOAD DATA LOCAL INFILE 'tpch_dbgen/lineitem.tbl'
INTO TABLE tbl_lineitem
FIELDS TERMINATED BY '|'
LINES TERMINATED BY '|\n'
(l_orderkey, l_partkey, l_suppkey, l_linenumber, l_quantity, l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus, l_shipdate, l_commitdate, l_receiptdate, l_shipinstruct, l_shipmode, l_comment);

-- Allocate group_id for Hermes encryption grouping
UPDATE tbl_lineitem SET group_id = (l_orderkey % 10) + 1;
EOF

echo "[*] TPC-H data load complete!"

echo '[*] Checking tbl_orders ...'
mysql -u $MYSQL_USER -D $MYSQL_DB -t -e 'SELECT COUNT(*) AS total_orders FROM tbl_orders;'
mysql -u $MYSQL_USER -D $MYSQL_DB -t -e 'SELECT o_orderkey, o_totalprice, group_id FROM tbl_orders LIMIT 3;'

echo ' '
echo '[*] Checking tbl_lineitem table...'
mysql -u $MYSQL_USER -D $MYSQL_DB -t -e 'SELECT COUNT(*) AS total_lineitems FROM tbl_lineitem;'
mysql -u $MYSQL_USER -D $MYSQL_DB -t -e 'SELECT l_orderkey, l_quantity, l_extendedprice, group_id FROM tbl_lineitem LIMIT 3;'
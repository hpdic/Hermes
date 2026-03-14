#!/bin/bash
set -e

export MYSQL_PWD='hpdic2023'
MYSQL_USER='hpdic'
MYSQL_DB='hermes_apps'

# 设置默认值
TABLE='tbl_bitcoin'
SIZE_PACK=128

# 解析具名参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--table)
      TABLE="$2"
      shift 2
      ;;
    -p|--pack)
      SIZE_PACK="$2"
      shift 2
      ;;
    -h|--help)
      echo 'Usage: $0 [-t table_name] [-p pack_size]'
      echo '  -t, --table   Specify the table (default: tbl_bitcoin)'
      echo '  -p, --pack    Specify the pack size (default: 128)'
      echo '                Must be a positive integer <= 8192.'
      exit 0
      ;;
    *)
      echo 'Unknown argument: $1'
      echo 'Run with -h or --help for usage.'
      exit 1
      ;;
  esac
done

PREFIX="${TABLE#tbl_}"  # e.g., tbl_bitcoin → bitcoin
OUT_DIR="./experiments/result/scale_${SIZE_PACK}"
mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/encrypt_${PREFIX}.txt"

echo "[*] Running encryption experiment on table: $TABLE" | tee "$OUT_FILE"
total_rows=$(mysql -u "$MYSQL_USER" -D "$MYSQL_DB" -sN -e "SELECT COUNT(*) FROM $TABLE;")
echo "[*] Total rows: $total_rows" | tee -a "$OUT_FILE"

#######################################
# Pack-based encryption timing
#######################################
echo "[*] Timing HERMES_PACK_CONVERT (group-wise)..." | tee -a "$OUT_FILE"

group_ids=$(mysql -u "$MYSQL_USER" -D "$MYSQL_DB" -sN -e "SELECT DISTINCT group_id FROM $TABLE ORDER BY group_id;")

start_pack=$(date +%s%3N)

for gid in $group_ids; do
  if [[ "$TABLE" == "tbl_bitcoin" ]]; then
    mysql -u "$MYSQL_USER" -D "$MYSQL_DB" -e "
      SELECT HERMES_PACK_CONVERT(FLOOR(value / 24)) FROM $TABLE WHERE group_id = $gid;" > /dev/null
  else
    mysql -u "$MYSQL_USER" -D "$MYSQL_DB" -e "
      SELECT HERMES_PACK_CONVERT(value) FROM $TABLE WHERE group_id = $gid;" > /dev/null
  fi
done

end_pack=$(date +%s%3N)
elapsed_pack=$((end_pack - start_pack))

echo "PACKED: total=${elapsed_pack} ms" | tee -a "$OUT_FILE"

#######################################
# Singular encryption timing
#######################################
echo "[*] Timing HERMES_ENC_SINGULAR (bulk SELECT)..." | tee -a "$OUT_FILE"

start_sing=$(date +%s%3N)

if [[ "$TABLE" == "tbl_bitcoin" ]]; then
  mysql -u "$MYSQL_USER" -D "$MYSQL_DB" -e "
    SELECT HERMES_ENC_SINGULAR(FLOOR(value / 24)) FROM $TABLE;" > /dev/null
else
  mysql -u "$MYSQL_USER" -D "$MYSQL_DB" -e "
    SELECT HERMES_ENC_SINGULAR(value) FROM $TABLE;" > /dev/null
fi

end_sing=$(date +%s%3N)
elapsed_sing=$((end_sing - start_sing))

echo "SINGULAR: total=${elapsed_sing} ms" | tee -a "$OUT_FILE"

#######################################
# Summary
#######################################
echo "" | tee -a "$OUT_FILE"
echo "------ Summary (table: $TABLE) ------" | tee -a "$OUT_FILE"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUT_FILE"
echo "Host: $(hostname)" | tee -a "$OUT_FILE"
echo "Kernel: $(uname -r)" | tee -a "$OUT_FILE"
echo "Total tuples: $total_rows" | tee -a "$OUT_FILE"
echo "Packed Encrypt:   $elapsed_pack ms (avg: $((elapsed_pack * 1000 / total_rows)) µs/row)" | tee -a "$OUT_FILE"
echo "Singular Encrypt: $elapsed_sing ms (avg: $((elapsed_sing * 1000 / total_rows)) µs/row)" | tee -a "$OUT_FILE"

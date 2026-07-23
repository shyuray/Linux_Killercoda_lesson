#!/bin/bash
# 第 3 章：檔案可讀但父目錄不給進入，另有一個權限過大的目錄
mkdir -p /srv/share/reports /srv/share/sales

[ -s /srv/share/reports/q2_summary.csv ] || \
  printf '部門,月份,金額\n業務部,2026-06,4230000\n' > /srv/share/reports/q2_summary.csv

chown -R sysadmin:appteam /srv/share/reports 2>/dev/null
chmod 644 /srv/share/reports/q2_summary.csv
chmod 750 /srv/share/reports

[ -f /srv/share/sales/note.txt ] || echo "業務部共用區" > /srv/share/sales/note.txt
chmod 777 /srv/share/sales

exit 0

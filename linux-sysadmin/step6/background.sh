#!/bin/bash
# 第 6 章：紀錄檔內容，以及一支必定失敗的服務
mkdir -p /var/log/app

if [ ! -s /var/log/app/order.log ] || ! grep -q "Permission denied" /var/log/app/order.log; then
  : > /var/log/app/order.log
  for i in $(seq 1 60); do
    printf '%s INFO  request handled\n' \
      "$(date -d "$i hours ago" '+%Y-%m-%d %H:%M:%S')" >> /var/log/app/order.log
  done
  printf '2026-07-23 03:14:22 ERROR failed to open /srv/app/data/orders.csv: Permission denied\n' >> /var/log/app/order.log
  printf '2026-07-23 03:14:23 ERROR worker exited unexpectedly\n' >> /var/log/app/order.log
fi

rm -f /opt/scripts/gen_report.sh
systemctl daemon-reload  >/dev/null 2>&1
systemctl start report-job >/dev/null 2>&1

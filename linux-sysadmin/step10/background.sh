#!/bin/bash
# 第 10 章：同時製造三個症狀，只給現象、不給方向

# 症狀一：訂單系統網頁打不開
systemctl stop order-web >/dev/null 2>&1

# 症狀二：人事目錄裡的檔案讀不到
mkdir -p /srv/share/hr
[ -f /srv/share/hr/salary.csv ] || echo "人事資料,請勿外流" > /srv/share/hr/salary.csv
chmod 000 /srv/share/hr/salary.csv

# 症狀三：備份區寫不進去
mkdir -p /var/lib/ops /srv/backup
if [ ! -f /var/lib/ops/backup.img ]; then
  dd if=/dev/zero of=/var/lib/ops/backup.img bs=1M count=100 status=none
  mkfs.ext4 -q -F /var/lib/ops/backup.img
fi
mountpoint -q /srv/backup || mount -o loop /var/lib/ops/backup.img /srv/backup
mkdir -p /srv/backup/daily

AVAIL=$(df -m /srv/backup 2>/dev/null | tail -1 | awk '{print $4}')
case "$AVAIL" in
  ''|*[!0-9]*) AVAIL=0 ;;
esac
if [ "$AVAIL" -gt 8 ]; then
  dd if=/dev/urandom of=/srv/backup/fill.dat bs=1M count=$((AVAIL - 4)) status=none 2>/dev/null
fi
exit 0

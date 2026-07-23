#!/bin/bash
# 第 9 章：備份區使用率拉高，另有一個肥大的紀錄檔
mkdir -p /var/lib/ops /srv/backup
if [ ! -f /var/lib/ops/backup.img ]; then
  dd if=/dev/zero of=/var/lib/ops/backup.img bs=1M count=100 status=none
  mkfs.ext4 -q -F /var/lib/ops/backup.img
fi
mountpoint -q /srv/backup || mount -o loop /var/lib/ops/backup.img /srv/backup

mkdir -p /srv/backup/daily
[ -f /srv/backup/daily/db-20260720.tar.gz ] || \
  dd if=/dev/urandom of=/srv/backup/daily/db-20260720.tar.gz bs=1M count=38 status=none
[ -f /srv/backup/daily/db-20260721.tar.gz ] || \
  dd if=/dev/urandom of=/srv/backup/daily/db-20260721.tar.gz bs=1M count=38 status=none

mkdir -p /var/log/app
if [ ! -f /var/log/app/access.log ] || [ "$(stat -c%s /var/log/app/access.log)" -lt 1000000 ]; then
  LINE='2026-07-23 00:00:01 INFO  request from 10.0.1.24 GET /orders 200'
  for i in $(seq 1 120000); do echo "$LINE"; done > /var/log/app/access.log
fi

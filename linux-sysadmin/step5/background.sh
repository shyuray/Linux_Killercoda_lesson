#!/bin/bash
# 第 5 章：訂單系統停止，且未設定開機自動啟動
systemctl daemon-reload    >/dev/null 2>&1
systemctl stop    order-web >/dev/null 2>&1
systemctl disable order-web >/dev/null 2>&1

mkdir -p /srv/app/www
[ -f /srv/app/www/index.html ] || echo "<h1>訂單查詢系統</h1>" > /srv/app/www/index.html

exit 0

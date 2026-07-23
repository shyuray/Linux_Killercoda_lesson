#!/bin/bash
# ==========================================================
#  Linux 系統管理課程 — 環境建置
#  在 intro 階段執行一次，建立十個章節所需的全部狀態。
#  學生可以直接跳到任何一章，不必先完成前面的章節。
# ==========================================================
export DEBIAN_FRONTEND=noninteractive

# ---------- 主機識別 ----------
hostnamectl set-hostname srv-app01 >/dev/null 2>&1 || echo srv-app01 > /etc/hostname
grep -q srv-app01 /etc/hosts || echo "127.0.1.1   srv-app01" >> /etc/hosts

# ---------- 群組與帳號 ----------
groupadd -f appteam
groupadd -f sales

id app-order  >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin -d /srv/app -c "order service"  app-order
id app-report >/dev/null 2>&1 || useradd -r -s /bin/false        -d /srv/app -c "report service" app-report
id sysadmin   >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,appteam -c "System Admin" sysadmin

# 第 4 章：已離職但帳號仍可登入
id wchen >/dev/null 2>&1 || useradd -m -s /bin/bash -c "Wu Chen" wchen
usermod -aG sudo,appteam wchen
echo 'wchen:OldPass2024' | chpasswd >/dev/null 2>&1

# ---------- 第 1 章：目錄結構與檔案 ----------
mkdir -p /srv/app/bin /srv/app/config /srv/app/data /srv/app/www
mkdir -p /srv/share/sales /srv/share/hr /srv/share/reports
mkdir -p /opt/scripts /var/log/app

cat > /srv/app/config/app.conf << 'EOF'
listen_port = 8080
data_dir    = /srv/app/data
log_file    = /var/log/app/order.log
EOF

echo "order_id,customer,amount"  > /srv/app/data/orders.csv
echo "10241,新光貿易,48200"     >> /srv/app/data/orders.csv
echo "10242,大同機械,15600"     >> /srv/app/data/orders.csv

: > /srv/app/data/orders_202607.csv          # 空檔案，第 1 章要找出它
echo "backup_enabled=true" > /srv/app/.settings   # 隱藏檔

printf '#!/bin/bash\n/usr/local/bin/order-web\n' > /srv/app/bin/start.sh
chmod 755 /srv/app/bin/start.sh

echo "<h1>訂單查詢系統</h1>" > /srv/app/www/index.html

# 修改時間拉開，讓第 1 章有東西可以比較
touch -d "8 months ago" /srv/app/bin/start.sh
touch -d "3 months ago" /srv/app/config/app.conf
touch -d "2 days ago"   /srv/app/data/orders.csv

# ---------- 第 2 章：散落在多層目錄裡的設定檔 ----------
mkdir -p /srv/app/config/modules /srv/app/config/legacy /srv/app/config/backup

for d in modules legacy backup; do
  for i in 1 2 3 4 5; do
    printf '# module %s config %s\ntimeout = 30\n' "$d" "$i" > "/srv/app/config/$d/mod$i.conf"
  done
done

# 唯一寫著舊資料庫位址的設定檔，第 2 章的搜尋目標
cat > /srv/app/config/legacy/db.conf << 'EOF'
# 舊資料庫連線設定，尚未移除
db_host = 192.168.10.50
db_port = 3306
EOF

# 干擾項：檔名相近但位址不同
echo "db_host = 192.168.10.88" > /srv/app/config/backup/db.conf.bak

# ---------- 第 3 章：檔案可讀，但父目錄不給進入 ----------
cat > /srv/share/reports/q2_summary.csv << 'EOF'
部門,月份,金額
業務部,2026-06,4230000
管理部,2026-06,860000
EOF

chown -R sysadmin:appteam /srv/share/reports
chmod 644 /srv/share/reports/q2_summary.csv   # 檔案本身人人可讀
chmod 750 /srv/share/reports                  # 但目錄不給 others 進入

# 對照組：權限開得過大的目錄
echo "業務部共用區" > /srv/share/sales/note.txt
chmod 777 /srv/share/sales

echo "人事資料,請勿外流" > /srv/share/hr/salary.csv
chmod 640 /srv/share/hr/salary.csv
chmod 750 /srv/share/hr

# ---------- 第 5 章：服務停止且未設定開機自動啟動 ----------
cat > /usr/local/bin/order-web << 'PYEOF'
#!/usr/bin/env python3
import http.server, socketserver, os
os.chdir("/srv/app/www")
with socketserver.TCPServer(("", 8080), http.server.SimpleHTTPRequestHandler) as s:
    s.serve_forever()
PYEOF
chmod 755 /usr/local/bin/order-web

cat > /etc/systemd/system/order-web.service << 'EOF'
[Unit]
Description=Order Query System
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/order-web
Restart=no

[Install]
WantedBy=multi-user.target
EOF

# ---------- 第 6 章：紀錄檔與一個必定失敗的服務 ----------
: > /var/log/app/order.log
for i in $(seq 1 60); do
  printf '%s INFO  request handled\n' \
    "$(date -d "$i hours ago" '+%Y-%m-%d %H:%M:%S')" >> /var/log/app/order.log
done
cat >> /var/log/app/order.log << 'EOF'
2026-07-23 03:14:22 ERROR failed to open /srv/app/data/orders.csv: Permission denied
2026-07-23 03:14:23 ERROR worker exited unexpectedly
EOF

# 這支服務指向不存在的腳本，啟動必定失敗，journal 會留下真實紀錄
cat > /etc/systemd/system/report-job.service << 'EOF'
[Unit]
Description=Monthly Report Job

[Service]
Type=oneshot
ExecStart=/opt/scripts/gen_report.sh
EOF

# ---------- 第 8 章：另一個服務，連接埠被別的程式佔用 ----------
cat > /usr/local/bin/report-api << 'PYEOF'
#!/usr/bin/env python3
import http.server, socketserver, os
os.chdir("/srv/app/www")
with socketserver.TCPServer(("", 9000), http.server.SimpleHTTPRequestHandler) as s:
    s.serve_forever()
PYEOF
chmod 755 /usr/local/bin/report-api

cat > /etc/systemd/system/report-api.service << 'EOF'
[Unit]
Description=Report API
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/report-api
Restart=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload >/dev/null 2>&1

# 啟動所有服務的初始狀態
systemctl stop    order-web >/dev/null 2>&1
systemctl disable order-web >/dev/null 2>&1
systemctl start   report-job >/dev/null 2>&1   # 失敗，紀錄寫進 journal

# 佔住 9000，讓 report-api 起不來
if ! ss -tulpn 2>/dev/null | grep -q ':9000'; then
  nohup python3 -m http.server 9000 --directory /tmp >/dev/null 2>&1 &
  sleep 2
fi
systemctl start report-api >/dev/null 2>&1

# ---------- 第 9 章：獨立掛載的備份區 ----------
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

# 肥大的紀錄檔，第 9 章要用 du 找出它
if [ ! -f /var/log/app/access.log ]; then
  LINE='2026-07-23 00:00:01 INFO  request from 10.0.1.24 GET /orders 200'
  for i in $(seq 1 120000); do echo "$LINE"; done > /var/log/app/access.log
fi

# ---------- 第 7 章：套件清單 ----------
apt-get update -qq >/dev/null 2>&1

# ---------- 第 8 章：防火牆規則已寫入但未啟用 ----------
if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp   >/dev/null 2>&1
  ufw allow 8080/tcp >/dev/null 2>&1
  ufw allow 9000/tcp >/dev/null 2>&1
fi

touch /tmp/setup-done
echo "環境建立完成"

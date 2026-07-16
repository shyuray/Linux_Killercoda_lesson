#!/bin/bash
# ============================================================
#  第三階段：連不到與磁碟 — 環境佈置
#  完成後建立 /tmp/scenario-ready
# ============================================================
export DEBIAN_FRONTEND=noninteractive
rm -f /tmp/scenario-ready

# ── 1. 安裝 nginx ──────────────────────────────────
apt-get update -qq >/dev/null 2>&1
apt-get install -y --no-install-recommends nginx >/dev/null 2>&1
command -v curl >/dev/null 2>&1 || apt-get install -y --no-install-recommends curl >/dev/null 2>&1
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done

systemctl enable nginx >/dev/null 2>&1
systemctl stop   nginx >/dev/null 2>&1

# ── 2. Stage 1：讓另一個程式先佔住 port 80 ───────────
mkdir -p /opt/legacy
cat > /opt/legacy/index.html << 'HTML'
<html><body><h1>Legacy test server</h1></body></html>
HTML
cd /opt/legacy
setsid python3 -m http.server 80 >/dev/null 2>&1 < /dev/null &
cd /
sleep 2

# nginx 啟動失敗（Address already in use）
systemctl start nginx >/dev/null 2>&1
sleep 1

# ── 3. Stage 2：報表 API，只綁 127.0.0.1 ─────────────
mkdir -p /opt/report-api
cat > /opt/report-api/index.html << 'HTML'
<html><body><h1>Report API</h1><p>status: ok</p></body></html>
HTML

cat > /etc/systemd/system/report-api.service << 'UNIT'
[Unit]
Description=Internal Report API
After=network.target

[Service]
WorkingDirectory=/opt/report-api
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 127.0.0.1
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload >/dev/null 2>&1
systemctl enable report-api >/dev/null 2>&1
systemctl start  report-api >/dev/null 2>&1

# ── 4. Stage 5、6：一顆用來放備份的小磁碟 ─────────────
#     刻意只給 32 個 inode，而且先塞滿
dd if=/dev/zero of=/opt/backup.img bs=1M count=16 >/dev/null 2>&1
mkfs.ext4 -N 32 -F /opt/backup.img >/dev/null 2>&1
mkdir -p /mnt/backup
mount -o loop /opt/backup.img /mnt/backup >/dev/null 2>&1
for i in $(seq 1 40); do touch /mnt/backup/session_$i.tmp 2>/dev/null; done
umount /mnt/backup >/dev/null 2>&1

# 寫進 fstab，但註解掉，Stage 5 會用到
grep -q "backup.img" /etc/fstab || \
  echo "# /opt/backup.img  /mnt/backup  ext4  loop  0  0" >> /etc/fstab

# ── 5. Stage 7：綜合診斷用的故障注入腳本 ──────────────
cat > /root/break.sh << 'BREAKEOF'
#!/bin/bash
[ "$EUID" -ne 0 ] && { echo "要用 sudo 執行"; exit 1; }

pkill -f "http.server 80" 2>/dev/null
sleep 1
[ -f /root/.m10-backup/default ] && cp /root/.m10-backup/default /etc/nginx/sites-enabled/default
mkdir -p /root/.m10-backup
cp /etc/nginx/sites-enabled/default /root/.m10-backup/default 2>/dev/null
chmod 755 /var/www/html/reports 2>/dev/null
systemctl enable nginx >/dev/null 2>&1
systemctl restart nginx >/dev/null 2>&1
sleep 1

FAULTS=(config perm port stop listen)
PICK=${FAULTS[$RANDOM % ${#FAULTS[@]}]}
echo "$PICK" > /root/.m10-answer
chmod 600 /root/.m10-answer

case "$PICK" in
  config)
    sed -i '0,/listen 80 default_server;/s//listen 80 default_server/' /etc/nginx/sites-enabled/default
    systemctl restart nginx >/dev/null 2>&1 ;;
  perm)
    mkdir -p /var/www/html/reports
    echo "2026 Q2 internal report" > /var/www/html/reports/report.txt
    chmod 644 /var/www/html/reports/report.txt
    chmod 750 /var/www/html/reports
    systemctl restart nginx >/dev/null 2>&1 ;;
  port)
    systemctl stop nginx >/dev/null 2>&1
    setsid python3 -m http.server 80 >/dev/null 2>&1 < /dev/null &
    sleep 1
    systemctl start nginx >/dev/null 2>&1 ;;
  stop)
    systemctl stop nginx >/dev/null 2>&1
    systemctl disable nginx >/dev/null 2>&1 ;;
  listen)
    sed -i 's/listen 80 default_server;/listen 127.0.0.1:80 default_server;/' /etc/nginx/sites-enabled/default
    sed -i '/listen \[::\]:80 default_server;/d' /etc/nginx/sites-enabled/default
    systemctl restart nginx >/dev/null 2>&1 ;;
esac

echo "現場已佈置完成。"
echo "同事回報：內部系統有問題。"
BREAKEOF

cat > /root/fix.sh << 'FIXEOF'
#!/bin/bash
[ "$EUID" -ne 0 ] && { echo "要用 sudo 執行"; exit 1; }
pkill -f "http.server 80" 2>/dev/null
sleep 1
[ -f /root/.m10-backup/default ] && cp /root/.m10-backup/default /etc/nginx/sites-enabled/default
chmod 755 /var/www/html/reports 2>/dev/null
systemctl enable nginx >/dev/null 2>&1
systemctl restart nginx >/dev/null 2>&1
sleep 1
if systemctl is-active nginx >/dev/null 2>&1; then
  echo "已還原，nginx 正常執行中。"
  [ -f /root/.m10-answer ] && echo "上一題的答案是：$(cat /root/.m10-answer)"
  rm -f /root/.m10-answer
else
  echo "還原失敗。手動檢查 systemctl status nginx"
fi
FIXEOF

chmod +x /root/break.sh /root/fix.sh

# ── 6. 驗證現場：nginx 必須是 failed、report-api 必須在跑 ──
if systemctl is-failed nginx >/dev/null 2>&1; then
  touch /tmp/scenario-ready
else
  systemctl restart nginx >/dev/null 2>&1
  sleep 1
  touch /tmp/scenario-ready
fi

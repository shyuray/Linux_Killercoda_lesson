#!/bin/bash
# ============================================================
#  Linux 系統除錯實戰 — 環境佈置（背景執行）
#  完成後會建立 /tmp/scenario-ready 作為就緒標記
# ============================================================

export DEBIAN_FRONTEND=noninteractive

rm -f /tmp/scenario-ready

# ── 1. 安裝 nginx ──────────────────────────────────
apt-get update -qq >/dev/null 2>&1
apt-get install -y --no-install-recommends nginx >/dev/null 2>&1
command -v curl >/dev/null 2>&1 || apt-get install -y --no-install-recommends curl >/dev/null 2>&1

# 等 apt 完全放開 dpkg 鎖，避免後續步驟被卡住
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done

# ── 2. 確認 nginx 這時候是正常的 ────────────────────
systemctl enable nginx >/dev/null 2>&1
systemctl start  nginx >/dev/null 2>&1
sleep 1

# ── 3. Stage 4 用：報表目錄，父目錄不給 others 執行權 ──
mkdir -p /var/www/html/reports
cat > /var/www/html/reports/report.txt << 'REPORT'
2026 Q2 內部報表
--------------------------------
營收：新台幣 42,300,000
部門：業務部 / 人資部 / 工程部
REPORT
chmod 644 /var/www/html/reports/report.txt
chmod 750 /var/www/html/reports

# ── 4. Stage 6 用：帶有攻擊痕跡的認證紀錄 ────────────
cat >> /var/log/auth.log << 'AUTHLOG'
Jul 10 01:22:11 srv sshd[1001]: Failed password for root from 203.0.113.45 port 51234 ssh2
Jul 10 01:22:13 srv sshd[1002]: Failed password for root from 203.0.113.45 port 51236 ssh2
Jul 10 01:22:15 srv sshd[1003]: Failed password for admin from 198.51.100.7 port 40122 ssh2
Jul 10 01:22:17 srv sshd[1004]: Failed password for root from 203.0.113.45 port 51240 ssh2
Jul 10 01:22:19 srv sshd[1005]: Failed password for root from 203.0.113.45 port 51242 ssh2
Jul 10 01:22:21 srv sshd[1006]: Failed password for root from 198.51.100.7 port 40130 ssh2
Jul 10 01:22:23 srv sshd[1007]: Failed password for test from 203.0.113.45 port 51244 ssh2
Jul 10 01:22:25 srv sshd[1008]: Failed password for root from 203.0.113.99 port 33221 ssh2
Jul 10 01:22:27 srv sshd[1009]: Failed password for root from 203.0.113.45 port 51250 ssh2
Jul 10 01:22:29 srv sshd[1010]: Failed password for admin from 198.51.100.7 port 40144 ssh2
Jul 10 01:22:31 srv sshd[1011]: Failed password for root from 203.0.113.45 port 51256 ssh2
Jul 10 01:22:33 srv sshd[1012]: Failed password for deploy from 203.0.113.45 port 51260 ssh2
Jul 10 01:22:35 srv sshd[1013]: Failed password for root from 203.0.113.45 port 51264 ssh2
Jul 10 01:22:37 srv sshd[1014]: Failed password for admin from 198.51.100.7 port 40150 ssh2
Jul 10 01:22:39 srv sshd[1015]: Failed password for root from 203.0.113.45 port 51268 ssh2
Jul 10 01:22:41 srv sshd[1016]: Accepted password for deploy from 203.0.113.45 port 51272 ssh2
Jul 10 01:22:43 srv sshd[1017]: Failed password for root from 198.51.100.7 port 40156 ssh2
AUTHLOG

# ── 5. Stage 5 用：一個肥大的紀錄檔（必須是有換行的文字）──
mkdir -p /var/log/nginx
LINE='2026/07/10 00:00:01 [notice] 1#1: signal process started; worker connections are not enough, reusing connections'
for i in $(seq 1 20000); do echo "$LINE"; done > /var/log/nginx/error.log
for i in $(seq 1 5); do
  cat /var/log/nginx/error.log /var/log/nginx/error.log > /tmp/e.tmp && mv /tmp/e.tmp /var/log/nginx/error.log
done
echo '2026/07/10 01:30:02 [error] 1234#0: *1 open() "/var/www/html/reports/report.txt" failed (13: Permission denied), client: 127.0.0.1, request: "GET /reports/report.txt HTTP/1.1"' >> /var/log/nginx/error.log

# ── 6. 製造故障：把設定檔某一行的分號拿掉 ─────────────
CONF=/etc/nginx/sites-enabled/default
sed -i '0,/listen 80 default_server;/s//listen 80 default_server/' "$CONF"

# ── 7. 讓服務進入 failed 狀態 ────────────────────────
systemctl restart nginx >/dev/null 2>&1
sleep 1

# ── 8. 驗證現場真的壞了，壞了才放行 ──────────────────
if systemctl is-failed nginx >/dev/null 2>&1; then
  touch /tmp/scenario-ready
else
  # 萬一沒壞成，再補一次
  sed -i '0,/listen 80 default_server;/s//listen 80 default_server/' "$CONF"
  systemctl restart nginx >/dev/null 2>&1
  sleep 1
  touch /tmp/scenario-ready
fi

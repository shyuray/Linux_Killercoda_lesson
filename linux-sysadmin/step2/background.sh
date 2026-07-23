#!/bin/bash
# 第 2 章：重新確立散落在多層目錄裡的設定檔
mkdir -p /srv/app/config/modules /srv/app/config/legacy /srv/app/config/backup

for d in modules legacy backup; do
  for i in 1 2 3 4 5; do
    [ -f "/srv/app/config/$d/mod$i.conf" ] || \
      printf '# module %s config %s\ntimeout = 30\n' "$d" "$i" > "/srv/app/config/$d/mod$i.conf"
  done
done

cat > /srv/app/config/legacy/db.conf << 'EOF'
# 舊資料庫連線設定，尚未移除
db_host = 192.168.10.50
db_port = 3306
EOF

echo "db_host = 192.168.10.88" > /srv/app/config/backup/db.conf.bak

exit 0

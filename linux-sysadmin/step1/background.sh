#!/bin/bash
# 第 1 章：重新確立目錄結構與檔案的修改時間
mkdir -p /srv/app/bin /srv/app/config /srv/app/data /srv/app/www

[ -s /srv/app/data/orders.csv ] || printf 'order_id,customer,amount\n10241,新光貿易,48200\n' > /srv/app/data/orders.csv
: > /srv/app/data/orders_202607.csv
[ -f /srv/app/.settings ]   || echo "backup_enabled=true" > /srv/app/.settings
[ -f /srv/app/bin/start.sh ] || printf '#!/bin/bash\n/usr/local/bin/order-web\n' > /srv/app/bin/start.sh
chmod 755 /srv/app/bin/start.sh

touch -d "8 months ago" /srv/app/bin/start.sh
touch -d "3 months ago" /srv/app/config/app.conf 2>/dev/null
touch -d "2 days ago"   /srv/app/data/orders.csv

exit 0

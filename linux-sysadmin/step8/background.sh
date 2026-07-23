#!/bin/bash
# 第 8 章：9000 埠被別的程式佔住，report-api 因此起不來；防火牆規則存在但未啟用
if ! ss -tulpn 2>/dev/null | grep -q ':9000'; then
  nohup python3 -m http.server 9000 --directory /tmp >/dev/null 2>&1 &
  sleep 2
fi

systemctl daemon-reload  >/dev/null 2>&1
systemctl restart report-api >/dev/null 2>&1

command -v ufw >/dev/null 2>&1 && ufw disable >/dev/null 2>&1

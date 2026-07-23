#!/bin/bash
# 第 4 章：離職者帳號仍可登入，且仍在管理員群組內
id wchen >/dev/null 2>&1 || useradd -m -s /bin/bash -c "Wu Chen" wchen
usermod -U wchen 2>/dev/null
usermod -s /bin/bash wchen
usermod -aG sudo,appteam wchen
echo 'wchen:OldPass2024' | chpasswd >/dev/null 2>&1

id app-report >/dev/null 2>&1 || \
  useradd -r -s /bin/false -d /srv/app -c "report service" app-report

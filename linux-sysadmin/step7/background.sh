#!/bin/bash
# 第 7 章：更新套件清單。setup.sh 已經更新過一次，
# 這裡再跑一次是為了讓資料新鮮，但不讓它阻塞或影響本章能否進入。
export DEBIAN_FRONTEND=noninteractive
timeout 60 apt-get update -qq >/dev/null 2>&1
exit 0

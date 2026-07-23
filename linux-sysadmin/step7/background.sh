#!/bin/bash
# 第 7 章：更新套件清單，讓版本比對有最新資料
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1

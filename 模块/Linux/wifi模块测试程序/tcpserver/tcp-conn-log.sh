#!/bin/sh
# 每秒记录一次当前与 TCP 端口(默认 1500)建立连接的客户端数量与 IP 到 CSV 文件
# 用法: ./tcp-conn-log.sh [端口] [输出文件]
#   默认: 端口 1500，输出 /lechi/tcp_clients.csv
# CSV 列: time,count,ips      (ips 字段含逗号，已用双引号包裹)
PORT=${1:-1500}
OUT=${2:-/lechi/tcp_clients.csv}

[ -f "$OUT" ] || echo "time,count,ips" > "$OUT"

while true; do
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    IPS=$(netstat -tn 2>/dev/null \
          | awk -v p=":$PORT" '$4 ~ (p"$") && $6=="ESTABLISHED" {print $5}' \
          | sed 's/:[0-9]*$//' | sort -u | tr '\n' ',' | sed 's/,$//')
    N=$(printf '%s' "$IPS" | tr ',' '\n' | grep -c .)
    echo "$TS,$N,\"$IPS\"" >> "$OUT"
    sleep 1
done

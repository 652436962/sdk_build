#!/bin/sh
# 统计当前与 TCP 端口(默认 1500)建立连接的客户端数量与 IP
# 用法: ./tcp-clients.sh [端口]
PORT=${1:-1500}

LIST=$(netstat -tn 2>/dev/null | awk -v p=":$PORT" '$4 ~ (p"$") && $6=="ESTABLISHED" {print $5}')
N=$(printf '%s\n' "$LIST" | grep -c .)
U=$(printf '%s\n' "$LIST" | sed 's/:[0-9]*$//' | sort -u | grep -c .)

echo "port=$PORT  connections=$N  unique clients=$U"
echo "---- per client (count / ip) ----"
[ "$N" -gt 0 ] && printf '%s\n' "$LIST" | sed 's/:[0-9]*$//' | sort | uniq -c | sort -rn

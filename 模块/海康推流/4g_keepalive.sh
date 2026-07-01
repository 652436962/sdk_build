#!/bin/sh
# /usr/local/bin/4g_keepalive.sh
# 4G 保活：每 30 秒检查外网，不通则重拨
PING_TARGET="8.8.8.8"
CHECK_INTERVAL=30

while true; do
    sleep ${CHECK_INTERVAL}

    ping -c 1 -W 5 ${PING_TARGET} >/dev/null 2>&1 && continue

    echo "[$(date)] 网络不通，重拨 4G..."
    killall udhcpc 2>/dev/null
    sleep 2

    udhcpc -i usb0
    sleep 3

    ifconfig eth0 192.168.1.1 netmask 255.255.255.0 up
    echo 1 > /proc/sys/net/ipv4/ip_forward

    iptables -t nat -C POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null || \
        iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE
    iptables -C FORWARD -i eth0 -o usb0 -j ACCEPT 2>/dev/null || \
        iptables -A FORWARD -i eth0 -o usb0 -j ACCEPT
    iptables -C FORWARD -i usb0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
        iptables -A FORWARD -i usb0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

    echo "[$(date)] 重拨完成"
done

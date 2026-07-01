#!/bin/sh
# ==============================================
# /etc/init.d/4g_route 或 /etc/rc.local
# 开机自启，保持4G在线，自动重拨
# ==============================================

ETH0_IP="192.168.1.1"
PING_TARGET="114.114.114.114"
CHECK_INTERVAL=30

setup_route() {
    # 开启转发
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # 配置 eth0
    ifconfig eth0 ${ETH0_IP} netmask 255.255.255.0 up

    # NAT 规则（幂等执行）
    iptables -t nat -C POSTROUTING -o usb0 -j MASQUERADE 2>/dev/null || \
        iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE

    iptables -C FORWARD -i eth0 -o usb0 -j ACCEPT 2>/dev/null || \
        iptables -A FORWARD -i eth0 -o usb0 -j ACCEPT

    iptables -C FORWARD -i usb0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
        iptables -A FORWARD -i usb0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
}

dial_4g() {
    echo "[$(date)] 4G拨号..."
    udhcpc -i usb0
}

check_and_redial() {
    # 检查 usb0 是否有 IP
    USB0_IP=$(ifconfig usb0 2>/dev/null | grep "inet addr" | cut -d: -f2 | awk '{print $1}')
    if [ -z "$USB0_IP" ]; then
        echo "[$(date)] usb0 无IP，重新拨号"
        dial_4g
        return
    fi

    # ping 检查连通性
    ping -c 1 -W 5 ${PING_TARGET} >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[$(date)] 网络不通，重新拨号"
        killall udhcpc 2>/dev/null
        sleep 2
        dial_4g
    fi
}

# ---- 启动 ----
dial_4g
sleep 3
setup_route

# ---- 循环守护 ----
while true; do
    sleep ${CHECK_INTERVAL}
    check_and_redial
done

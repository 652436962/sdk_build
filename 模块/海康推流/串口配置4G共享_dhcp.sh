#!/bin/sh
# ==============================================
# 完整版: eth0 通过 usb0(4G) 上网 + DHCP 自动分配
# 下联设备插 eth0 即可自动获取 IP 上网
# ==============================================

ETH0_IP="192.168.1.1"
ETH0_NETMASK="255.255.255.0"
DHCP_RANGE_START="192.168.1.100"
DHCP_RANGE_END="192.168.1.200"

# ---- 1. 4G 模块拨号 ----
echo ">>> 4G模块拨号..."
udhcpc -i usb0
sleep 3

# ---- 2. 配置 eth0 静态IP ----
echo ">>> 配置 eth0: ${ETH0_IP}"
ifconfig eth0 ${ETH0_IP} netmask ${ETH0_NETMASK} up

# ---- 3. 开启 IP 转发 ----
echo ">>> 开启 IP 转发"
echo 1 > /proc/sys/net/ipv4/ip_forward

# ---- 4. NAT 转发 ----
echo ">>> 配置 NAT"
iptables -t nat -F
iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE
iptables -F FORWARD
iptables -A FORWARD -i eth0 -o usb0 -j ACCEPT
iptables -A FORWARD -i usb0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# ---- 5. DHCP 服务 (dnsmasq) ----
echo ">>> 启动 DHCP 服务"
# 杀掉旧进程
killall dnsmasq 2>/dev/null

# 如果没安装则用 busybox 自带 udhcpd 替代
if command -v dnsmasq >/dev/null 2>&1; then
    dnsmasq --interface=eth0 \
        --dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},12h \
        --dhcp-option=3,${ETH0_IP} \
        --dhcp-option=6,114.114.114.114,8.8.8.8 \
        --no-daemon &
elif command -v udhcpd >/dev/null 2>&1; then
    cat > /tmp/udhcpd.conf <<EOF
interface eth0
start   ${DHCP_RANGE_START}
end     ${DHCP_RANGE_END}
opt dns 114.114.114.114 8.8.8.8
opt router ${ETH0_IP}
opt subnet ${ETH0_NETMASK}
EOF
    udhcpd /tmp/udhcpd.conf &
else
    echo "!!! 未找到 dnsmasq/udhcpd，DHCP 不可用"
    echo "    下联设备请手动设 IP: ${ETH0_IP%.*}.x 网关: ${ETH0_IP}"
fi

echo ""
echo "===================================="
echo "  配置完成"
echo "  eth0: ${ETH0_IP}"
echo "  4G:   usb0"
echo "  DHCP: ${DHCP_RANGE_START} ~ ${DHCP_RANGE_END}"
echo "===================================="

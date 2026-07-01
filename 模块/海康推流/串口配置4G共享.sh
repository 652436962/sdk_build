#!/bin/sh
# ==============================================
# 串口连接设备后执行，使 eth0 通过 usb0(4G) 上网
# eth0 下联设备，usb0 为4G模块出口
# ==============================================

# eth0 局域网配置
ETH0_IP="192.168.1.1"
ETH0_NETMASK="255.255.255.0"

# ---- 1. 4G 模块拨号 ----
echo ">>> 4G模块拨号..."
udhcpc -i usb0

# 等待获取IP
sleep 3

# ---- 2. 配置 eth0 静态IP ----
echo ">>> 配置 eth0 静态 IP: ${ETH0_IP}"
ifconfig eth0 ${ETH0_IP} netmask ${ETH0_NETMASK} up

# ---- 3. 开启内核 IP 转发 ----
echo ">>> 开启 IP 转发..."
echo 1 > /proc/sys/net/ipv4/ip_forward
# 持久化（如果 /etc/sysctl.conf 存在）
grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf 2>/dev/null || \
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# ---- 4. 配置 NAT 转发 (iptables) ----
echo ">>> 配置 NAT 规则..."
iptables -t nat -F
iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE
iptables -F FORWARD
iptables -A FORWARD -i eth0 -o usb0 -j ACCEPT
iptables -A FORWARD -i usb0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# ---- 5. 下联设备配置方式（二选一） ----
echo ""
echo "===================================="
echo "  配置完成"
echo "  eth0: ${ETH0_IP}"
echo "  4G出口: usb0"
echo "===================================="
echo ""
echo "下联设备 (接eth0) 网络设置:"
echo "  IP:    192.168.1.x (x=2~254)"
echo "  掩码:  255.255.255.0"
echo "  网关:  ${ETH0_IP}"
echo "  DNS:   114.114.114.114 或 8.8.8.8"

#!/bin/sh
# 幂等的 WiFi AP 启动脚本（OK3562 / QCA9880 / wlp1s0）
# 关键点：等待接口出现 + hostapd 重试，避免开机时序导致的启动失败
WIFI=wlp1s0

# 1) 清理旧进程（避免重复启动抢接口）
killall hostapd dnsmasq 2>/dev/null
sleep 1

# 2) 加载驱动
modprobe ath10k_pci 2>/dev/null

# 3) 等接口出现（ath10k 加载完固件后才会创建 wlp1s0），最多等 20s
i=0
while [ ! -e /sys/class/net/$WIFI ] && [ $i -lt 20 ]; do sleep 1; i=$((i+1)); done
[ -e /sys/class/net/$WIFI ] || { echo "[wifi-ap] no $WIFI"; exit 1; }

# 4) 重置接口并配置 AP 地址
ip link set $WIFI down 2>/dev/null
ip link set $WIFI up
ip addr flush dev $WIFI 2>/dev/null
ip addr add 192.168.100.1/24 dev $WIFI 2>/dev/null

# 5) 启动 hostapd，失败重试 5 次
n=0
while [ $n -lt 5 ]; do
  hostapd -B /etc/hostapd-wlp1s0.conf && break
  n=$((n+1)); sleep 1
done
[ $n -lt 5 ] || { echo "[wifi-ap] hostapd failed"; exit 1; }

# 6) 启动 DHCP
sleep 1
dnsmasq -C /etc/dnsmasq-wlp1s0.conf 2>/dev/null

echo "[wifi-ap] up: $(ifconfig $WIFI | sed -n "2p")"
exit 0

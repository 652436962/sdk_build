#!/bin/sh
# ==============================================
# 海康摄像头端口转发 + 4G共享 (一次性执行)
# 摄像头接 eth0 局域网，通过 4G 对外推流时可选
# ==============================================

CAM_IP="192.168.1.64"      # 摄像头在 eth0 局域网内的 IP
RTSP_PORT="554"              # 摄像头 RTSP 端口

# ---- 1-4 同前：拨号、eth0、转发、NAT ----
udhcpc -i usb0
sleep 3
ifconfig eth0 192.168.10.1 netmask 255.255.255.0 up
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -F
iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE
iptables -F FORWARD
iptables -A FORWARD -i eth0 -o usb0 -j ACCEPT
iptables -A FORWARD -i usb0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# ---- 5. 端口转发：外部访问 usb0:8554 -> 摄像头:554 ----
iptables -t nat -A PREROUTING -i usb0 -p tcp --dport 8554 -j DNAT --to-destination ${CAM_IP}:${RTSP_PORT}
iptables -A FORWARD -p tcp -d ${CAM_IP} --dport ${RTSP_PORT} -j ACCEPT

echo ">>> RTSP 端口转发: usb0:8554 -> ${CAM_IP}:${RTSP_PORT}"
echo ">>> 外部拉流: rtsp://admin:password@<4G公网IP>:8554/Streaming/Channels/101"

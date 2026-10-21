#!/bin/sh
# WiFi AP 控制脚本 (RTL8723DS)
# 用法: wifi_ap.sh {start|stop|restart}
IFACE=wlan0
IPADDR=172.31.100.1
NETMASK=255.255.0.0
SSID=test
PWD=test123456
CHANNEL=6
CONF=/etc/hostapd/hostapd.conf

start() {
    cat > $CONF <<EOF
interface=$IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
ieee80211n=1
wpa=2
wpa_passphrase=$PWD
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
    ifconfig $IFACE up
    ip addr flush dev $IFACE 2>/dev/null
    ifconfig $IFACE $IPADDR netmask $NETMASK
    pkill hostapd 2>/dev/null
    sleep 1
    hostapd -B $CONF
    sleep 2
    echo "AP started: ssid=$SSID ip=$IPADDR/$NETMASK"
    iw dev $IFACE info
}

stop() {
    pkill hostapd 2>/dev/null
    ifconfig $IFACE down 2>/dev/null
    echo "AP stopped"
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 1; start ;;
    *) echo "usage: $0 {start|stop|restart}"; exit 1 ;;
esac

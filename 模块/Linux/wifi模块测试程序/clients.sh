#!/bin/sh
# 打印当前连接到本板 WiFi 热点的客户端数量与 IP
# 用法: ./clients.sh [无线接口]    不指定则自动探测(优先 AP 模式，如 wlan0/wlp1s0)
WIFI=${1:-}

if [ -z "$WIFI" ]; then
    # 1) 优先 type AP 的接口
    for iface in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do
        [ "$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}')" = "AP" ] && { WIFI=$iface; break; }
    done
    # 2) 否则优先常见无线名(跳过 p2p*)
    if [ -z "$WIFI" ]; then
        for iface in wlan0 wlp1s0 wlan1; do
            iw dev "$iface" info >/dev/null 2>&1 && { WIFI=$iface; break; }
        done
    fi
    # 3) 再退而求其次：第一个非 p2p 无线接口
    if [ -z "$WIFI" ]; then
        for iface in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do
            case "$iface" in p2p*) ;; *) WIFI=$iface; break ;; esac
        done
    fi
fi

if [ -z "$WIFI" ]; then
    echo "no wireless interface found"
    exit 1
fi

STA=$(iw dev "$WIFI" station dump 2>/dev/null)
N=$(echo "$STA" | grep -c '^Station')

echo "wifi=$WIFI  connected clients: $N"
printf "%-18s %-16s %s\n" MAC IP SIGNAL

echo "$STA" | awk '/^Station/{print $2}' | while read mac; do
    [ -z "$mac" ] && continue
    ip=$(awk -v m="$mac" 'BEGIN{IGNORECASE=1} $4==m && $1!="0.0.0.0"{print $1; exit}' /proc/net/arp)
    sig=$(echo "$STA" | awk -v m="$mac" '$0~m{f=1} f&&/signal:/{print $2; exit}')
    printf "%-18s %-16s %s\n" "$mac" "${ip:-none}" "${sig:-?}"
done

# RTL8723DS AP 模式脚本

用于在 RK3562（TL3562-EVM-SDIO-WIFI）上，把 RTL8723DS 的 `wlan0` 配置为 **AP 模式**。

## 文件

| 文件 | 说明 |
|------|------|
| `wifi_ap.sh` | AP 控制脚本（start / stop / restart） |
| `hostapd.conf` | 脚本生成的 hostapd 配置（当前默认值） |

板卡实际路径：脚本 `/lechi/wifi_ap.sh`、配置 `/etc/hostapd/hostapd.conf`。

## 默认参数

| 项 | 值 |
|----|----|
| 接口 | `wlan0` |
| SSID | `test` |
| 密码 | `test123456` |
| 加密 | WPA2-PSK / CCMP |
| 信道 | `6`（2.4GHz） |
| IP | `172.31.100.1` |
| 掩码 | `255.255.0.0`（/16） |

## 用法

```sh
/lechi/wifi_ap.sh start     # 开启 AP
/lechi/wifi_ap.sh stop      # 关闭 AP
/lechi/wifi_ap.sh restart   # 重启 AP
```

脚本动作：写 `/etc/hostapd/hostapd.conf` → 拉起 `wlan0` 并配 IP/掩码 → 启动 `hostapd`。

## 修改参数

编辑 `wifi_ap.sh` 顶部变量即可：

```sh
IFACE=wlan0
IPADDR=172.31.100.1
NETMASK=255.255.0.0
SSID=test
PWD=test123456
CHANNEL=6
```

## 依赖

`hostapd`、`iw`、`ifconfig`（Ubuntu rootfs 自带）。

## 实测输出

```
Interface wlan0
	type AP
	ssid test
	channel 6 (2437 MHz), width: 20 MHz
wlan0  UP  172.31.100.1/16
```

## 说明

- 未启用 DHCP 服务器：客户端需手动配置同网段（`172.31.0.0/16`）静态 IP。
- 未做开机自启：当前为手动/脚本启动。

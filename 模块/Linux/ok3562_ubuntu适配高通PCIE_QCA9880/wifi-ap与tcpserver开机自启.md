# OK3562 (Ubuntu 20.04) WiFi 热点 + tcpserver 开机自启

> 板卡：OK3562（forlinx，Ubuntu 20.04，kernel 5.10.198）
> 无线：QCA9880（`ath10k_pci`，接口 `wlp1s0`）
> 验证日期：2026-10-21
>
> 踩坑与失败过程单独记录在：[wifi-ap失败排查记录.md](./wifi-ap失败排查记录.md)

## 结论（已实测）

一次真实 `reboot` 后：

| 服务 | enabled | 重启后 active | 证据 |
|------|---------|--------------|------|
| `wifi-ap` | enabled | active | hostapd 日志 `wlp1s0: AP-ENABLED`，`dnsmasq` 已绑定 DHCP |
| `tcpserver` | enabled | active | `ss -lnt` 显示 `0.0.0.0:1500`，主机可 connect |

主机侧扫描结果：

```
00:0E:8E:BF:5A:D0  test  ch6  信号 67
```

## 参数

| 项 | 值 |
|----|----|
| SSID | `test` |
| 密码 | `test123456` |
| 加密 | WPA2-PSK / CCMP |
| 信道 | 6（2.4G，`hw_mode=g`） |
| AP 地址 | `192.168.100.1/24` |
| DHCP 池 | `192.168.100.100 ~ 192.168.100.200`，租期 12h |
| tcpserver | `0.0.0.0:1500`，日志 `/opt/tcpserver/logs` |

## 关键踩坑：NetworkManager 抢接口

**现象**：服务 `active`、hostapd 进程在，但主机扫不到 SSID；journal 里出现
`wpa_supplicant: wlp1s0: CTRL-EVENT-SCAN-FAILED ret=-95`，`tx_packets` 不增长。

**原因**：`NetworkManager` 同时在管理 `wlp1s0`，其 `wpa_supplicant` 与 hostapd 争抢同一网卡，导致 AP 无法正常发信标。

**解决**：让 NM 忽略该接口（`unmanaged`）：

```bash
sudo mkdir -p /etc/NetworkManager/conf.d
printf '[keyfile]\nunmanaged-devices=interface-name:wlp1s0\n' \
  | sudo tee /etc/NetworkManager/conf.d/99-unmanaged-wlp1s0.conf
sudo systemctl restart NetworkManager      # 注意：reload 不生效，必须 restart
nmcli -t -f DEVICE,STATE dev status | grep wlp1s0   # 期望 wlp1s0:unmanaged
```

> `nmcli ... | grep wlp1s0` 显示 `unmanaged` 才算成功；显示 `disconnected` 说明配置未生效（文件为空或只做了 reload）。
> 重启 NetworkManager 不影响 `eth0`（192.168.1.111 由 systemd-networkd 管理）。

## 第二个坑：开机时序

开机时服务跑得比 `wlp1s0` 出现更早，`hostapd` 失败 → 服务退出码 2（`failed`）。

**解决**：用幂等脚本 `wifi-ap.sh`：
1. 先杀旧 `hostapd`/`dnsmasq`；
2. `modprobe ath10k_pci`；
3. **轮询等 `/sys/class/net/wlp1s0` 出现（最多 20s）**；
4. 重置接口 + 配 IP；
5. `hostapd -B` **失败重试 5 次**；
6. 启动 `dnsmasq`。

## 部署步骤

```bash
# 1. hostapd / dnsmasq（板子无外网，从 SDK sysroot 拷贝 hostapd）
sudo cp hostapd /usr/sbin/hostapd && sudo chmod +x /usr/sbin/hostapd

# 2. AP 配置
sudo cp files/hostapd-wlp1s0.conf  /etc/hostapd-wlp1s0.conf
sudo cp files/dnsmasq-wlp1s0.conf  /etc/dnsmasq-wlp1s0.conf

# 3. 让 NetworkManager 忽略 wlp1s0
sudo cp files/99-unmanaged-wlp1s0.conf /etc/NetworkManager/conf.d/
sudo systemctl restart NetworkManager

# 4. 启动脚本 + 服务
sudo cp files/wifi-ap.sh /usr/local/sbin/wifi-ap.sh
sudo chmod +x /usr/local/sbin/wifi-ap.sh
sudo cp files/wifi-ap.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wifi-ap

# 5. tcpserver
sudo cp files/tcpserver.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tcpserver
```

## 验证

```bash
# 服务状态
for s in wifi-ap tcpserver; do
  echo "$s: enabled=$(systemctl is-enabled $s) active=$(systemctl is-active $s)"
done

# AP
pgrep -a hostapd; pgrep -a dnsmasq
ifconfig wlp1s0 | sed -n '2p'          # 192.168.100.1

# hostapd 是否真的 AP-ENABLED（关键！只看进程存在不够）
sudo journalctl -u wifi-ap --no-pager | grep -E 'AP-ENABLED|interface state'

# tcpserver
ss -lnt | grep :1500

# 主机侧
nmcli dev wifi rescan; sleep 5
nmcli -t -f BSSID,SSID,SIGNAL,CHAN dev wifi list | grep -i test
```

## 排查清单

| 现象 | 原因 | 处理 |
|------|------|------|
| 服务 `failed`，退出码 2 | 开机时序，`wlp1s0` 未就绪 | 使用 `wifi-ap.sh`（等待接口 + 重试） |
| 进程在但扫不到 SSID | NetworkManager 抢接口 | 配置 `unmanaged-devices` 并 **restart** NM |
| 扫到但连不上 / 拿不到 IP | dnsmasq 未起 | `pgrep dnsmasq`、`journalctl -u wifi-ap` |
| `hostapd` 启动报 `could not set interface flags` | 接口被别的进程占用 | `killall hostapd wpa_supplicant` 后重启服务 |
| 反复重启后 AP 异常 | ath10k 固件状态错乱 | `modprobe -r ath10k_pci && modprobe ath10k_pci` |

## 备注

- `tx_packets` 在 ath10k 上不统计信标（由固件发送），**不能**用它判断 AP 是否工作；以 `AP-ENABLED` 日志 + 主机扫描为准。
- 主机扫不到 SSID 有时是**扫描侧漏报**（主机本身连在 ch6 上时），多扫几次或换台设备连接确认。
- 所有配置文件原件存于本目录 `files/`，可直接拷到新板复用。

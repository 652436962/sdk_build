# WiFi 热点（wlp1s0）启动失败 —— 完整排查与失败记录

> 板卡：OK3562（Ubuntu 20.04，kernel 5.10.198），无线：QCA9880 / `ath10k_pci` / `wlp1s0`
> 记录日期：2026-10-21
> 关联文档：[wifi-ap与tcpserver开机自启.md](./wifi-ap与tcpserver开机自启.md)
>
> **注**：排查当时热点地址为 `172.31.100.1/16`，现已改为 `192.168.100.1/24`；
> 下文中出现的 `172.31.x` 为**当时实际的命令记录**，保留原值以还原过程。

本文记录**从"启动失败"到"开机自启稳定"过程中所有踩过的坑**，包括当时的错误判断，避免重复走弯路。

---

## 一、最终结论

| 问题 | 根因 | 状态 |
|------|------|------|
| 开机后 `wifi-ap` 状态 `failed`（退出码 2） | 服务启动早于 `wlp1s0` 就绪，hostapd 失败 | 已修复 |
| 服务 `active` 但主机扫不到 SSID | NetworkManager 的 `wpa_supplicant` 抢占 `wlp1s0` | 已修复 |
| `unmanaged` 配置写了却不生效 | heredoc 在 ssh 单引号内没写入文件（文件为空）+ NM 只 `reload` | 已修复 |
| 反复重启后 AP 异常 | 多次 stop/start 使 ath10k 固件状态错乱 | 已确认可恢复 |
| 主机扫描时有时无 | 主机自身连在 ch6，扫描漏报（非板端问题） | 已知，非缺陷 |

一次真实 `reboot` 后：`wifi-ap`、`tcpserver` 均 `active`，hostapd 日志 `AP-ENABLED`，主机扫到 `test`（ch6，信号 67），`1500` 端口可连。

---

## 二、失败 #1：开机 `wifi-ap` 直接 failed

### 现象

```
× wifi-ap.service - WiFi AP on wlp1s0 (hostapd + dnsmasq)
     Active: failed (Result: exit-code) since Wed 2026-10-21 09:00:40 CST
    Process: 751 ExecStart=/bin/sh -c ... (code=exited, status=2)
```

同时：

```
pgrep hostapd      → 空
pgrep dnsmasq      → 空
ifconfig wlp1s0    → flags=4099<UP,BROADCAST,MULTICAST>，无 inet
lsmod | grep ath10k → ath10k_pci / ath10k_core 已加载
```

文件都在：

```
-rwxr-xr-x /usr/sbin/hostapd
-rw-r--r-- /etc/hostapd-wlp1s0.conf
-rw-r--r-- /etc/dnsmasq-wlp1s0.conf
```

### 当时的错误判断

1. ~~以为是镜像被重刷、hostapd 和配置丢了~~ → 文件都在，排除。
2. ~~以为是 hostapd 二进制不兼容~~ → 手动跑正常，排除。

### 定位方法

把原 `ExecStart` 那一长串 `sh -c` 拆开逐步手动执行：

```sh
sudo modprobe ath10k_pci;            echo "modprobe rc=$?"
sudo ip link set wlp1s0 down;        echo "down rc=$?"
sudo ip link set wlp1s0 up;          echo "up rc=$?"
sudo ip addr flush dev wlp1s0;       echo "flush rc=$?"
sudo ip addr add 172.31.100.1/16 dev wlp1s0; echo "add rc=$?"
sudo hostapd -B /etc/hostapd-wlp1s0.conf;    echo "hostapd rc=$?"
sudo dnsmasq -C /etc/dnsmasq-wlp1s0.conf;    echo "dnsmasq rc=$?"
```

结果全部 `rc=0`，hostapd 输出 `AP-ENABLED`。

### 根因

**开机时序竞争**：`multi-user.target` 时 `ath10k` 尚未加载完固件、`wlp1s0` 还不存在，
`ip link set wlp1s0` / `hostapd` 直接失败，整条 `sh -c` 返回 2。

### 修复

1. 把内联命令串改成脚本 `/usr/local/sbin/wifi-ap.sh`（便于调试、可重入）。
2. 脚本内**轮询等待接口出现**（最多 20s）：
   ```sh
   i=0
   while [ ! -e /sys/class/net/wlp1s0 ] && [ $i -lt 20 ]; do sleep 1; i=$((i+1)); done
   ```
3. `hostapd -B` **失败重试 5 次**。
4. 顶部先 `killall hostapd dnsmasq`，保证幂等（重复 start 不抢接口）。
5. service 改 `Type=oneshot` + `RemainAfterExit=yes`。

### 经验

> 开机自启的 AP 服务**绝不能**假设网卡已经存在。等 `/sys/class/net/<if>` 是最省事、
> 最可靠的"驱动+固件就绪"判据（ath10k 是先加载固件才创建接口）。

---

## 三、失败 #2：服务 active，但主机扫不到 SSID

### 现象

修复时序后服务 `active`、hostapd 进程在、`wlp1s0` 有 `172.31.100.1`，但：

```
nmcli ... dev wifi list | grep -i test   → 空
```

板端：

```
tx_packets: 14 -> 14      (3 秒内不增长)
journalctl | grep hostapd → 只有 "Configuration file: ..."，没有 "AP-ENABLED"
```

### 当时的错误判断

1. ~~以为是 hostapd 后台启动失败（没到 AP-ENABLED）~~ → 前台跑一次仍 `AP-ENABLED`，排除。
2. ~~以为是信道 6 被占用 / 法规限制~~ → 前台正常，排除。
3. ~~以 `tx_packets` 不增长判定"信标没发"~~ → **这是误判**，见下方"认知修正"。

### 真正的线索

journal 里反复出现：

```
wpa_supplicant[582]: wlp1s0: CTRL-EVENT-SCAN-FAILED ret=-95
NetworkManager[514]: device (wlp1s0): supplicant interface state: inactive -> disconnected
```

即 **NetworkManager 也在管理 `wlp1s0`**，它的 `wpa_supplicant` 与 hostapd 争抢同一张网卡，
导致 AP 无法正常建立/发信标。

### 修复

让 NetworkManager 忽略该接口：

```bash
sudo mkdir -p /etc/NetworkManager/conf.d
printf '[keyfile]\nunmanaged-devices=interface-name:wlp1s0\n' \
  | sudo tee /etc/NetworkManager/conf.d/99-unmanaged-wlp1s0.conf
sudo systemctl restart NetworkManager
nmcli -t -f DEVICE,STATE dev status | grep wlp1s0   # 必须看到 unmanaged
```

> 重启 NM 不影响 `eth0`（`192.168.1.111` 由 systemd-networkd 管理），SSH 不会断。

### 认知修正（重要）

`/sys/class/net/wlp1s0/statistics/tx_packets` 在 ath10k 上**不统计信标帧**
（beacon 由固件直接发送），所以它不增长**不代表 AP 没工作**。

判断 AP 是否真的起来的**唯一可靠依据**：

1. hostapd 日志出现 `wlp1s0: interface state ... AP-ENABLED`；
2. 另一台设备能扫到/连上 SSID。

---

## 四、失败 #3：`unmanaged-devices` 写了却不生效

### 现象

按上一步操作后一度看到 `wlp1s0:unmanaged`，但重启后又是 `wlp1s0:disconnected`：

```bash
cat /etc/NetworkManager/conf.d/99-unmanaged-wlp1s0.conf   # 输出为空！
```

### 根因（两个叠加）

1. **heredoc 没写进文件**：在 `ssh '...'` 的单引号串里用
   `sudo tee file >/dev/null <<EOF ... EOF`，文件被创建但内容为空。
2. **`reload` 不生效**：`unmanaged-devices` 属于启动期读取的配置，
   `systemctl reload NetworkManager` 不会重新应用，**必须 `restart`**。

### 修复

用 `printf | sudo tee` 且**当场 `cat` 校验内容**，再 `restart`：

```bash
printf '[keyfile]\nunmanaged-devices=interface-name:wlp1s0\n' \
  | sudo tee /etc/NetworkManager/conf.d/99-unmanaged-wlp1s0.conf
cat /etc/NetworkManager/conf.d/99-unmanaged-wlp1s0.conf     # 必须能看到两行
sudo systemctl restart NetworkManager
```

### 经验

> 用 `sudo tee` 写系统配置后，**紧跟一条 `cat` 校验**。空文件是"看起来成功"的典型陷阱，
> 尤其在多层引号的 ssh 命令里。

---

## 五、失败 #4：反复 stop/start 后 AP 行为异常

### 现象

连续 `systemctl stop/restart wifi-ap`、手动 `hostapd` 多次后：

- 服务 `active`，但主机长时间扫不到；
- dmesg 反复刷：
  ```
  ath10k_pci 0000:01:00.0: pdev param 0 not supported by firmware
  ```

### 定位

前台直接跑 hostapd 观察完整输出：

```bash
sudo timeout 8 hostapd /etc/hostapd-wlp1s0.conf 2>&1 | tail -25
```

输出干净地到达：

```
wlp1s0: interface state UNINITIALIZED->ENABLED
wlp1s0: AP-ENABLED
```

说明 hostapd/配置本身没问题，是**驱动/固件状态**被反复启停弄乱了。

### 修复

重载驱动模块复位固件：

```bash
sudo systemctl stop wifi-ap
sudo killall hostapd dnsmasq
sudo modprobe -r ath10k_pci && sleep 2 && sudo modprobe ath10k_pci
sleep 4
sudo systemctl start wifi-ap
```

### 备注

`pdev param 0 not supported by firmware` 是 ath10k + 该固件的**已知无害提示**，
不是故障原因，不要被它带偏。

---

## 六、失败 #5（假故障）：主机扫描时有时无

### 现象

同一时刻板端 `AP-ENABLED`、另一台设备能连，但本机 `nmcli dev wifi list` 里没有 `test`；
连续扫 3 次，偶尔第 3 次才出现。

### 结论：**不是板端问题**

排查环境：本机（`wlp7s0`）正连着 `TP-LINK_C77A`，且该 AP 也在 **ch6**，
与 `test` 同信道 —— 连接态下的扫描对同信道 BSS 容易漏报。

### 处理

- 多扫几次（本机脚本已做 3 次重试）；
- 或换一台未连接同信道 AP 的设备确认；
- **不要**据此判定热点失败。

### 经验

> 验证 AP 可用性时，优先用"另一台设备实际连接并拿到 DHCP 地址"，
> 而不是依赖单次扫描结果。

---

## 七、附带记录的其它失败

### 7.1 板子没有 hostapd / iw，且无外网

- 现象：`hostapd: command not found`。
- 处理：从 SDK sysroot 拷 aarch64 二进制
  `rk3562_sdk/ubuntu/rk3562-ubuntu20.04-sdk/.../sysroots/armv8a-linux/usr/sbin/hostapd`
  到板端 `/usr/sbin/hostapd` 并 `chmod +x`。
- `iw` 未装，改用 `ifconfig` + `/sys/class/net/*` + hostapd 日志替代。

### 7.2 配置在重刷镜像后丢失

- 现象：重刷 `update.img` 后 `/etc/hostapd-wlp1s0.conf`、`/etc/dnsmasq-wlp1s0.conf`、
  `/usr/sbin/hostapd` 全没了，服务 `failed`。
- 原因：这些是**运行时手工文件**，不在 rootfs 构建里。
- 处理：本次已把原件固化到仓库 `files/`，重刷后按
  [wifi-ap与tcpserver开机自启.md](./wifi-ap与tcpserver开机自启.md) "部署步骤" 一次性恢复。
- **改进建议**：把这些文件加进 rootfs overlay，做到"刷完即用"。

### 7.3 镜像烧写失败：分区大于 flash

- 现象：烧写 `update.img` 报
  `Note: Definition of partition in the firmware is larger than flash`。
- 原因：为塞进 ath10k 模块+固件，rootfs 扩到 12G，超过实际 flash。
- 处理：缩小 `parameter-ubuntu-fit.txt` 中 rootfs 大小（`0x00B10000` 起算），重新打包 `update.img`。

### 7.4 AP6275S（SDIO WiFi 模组）—— 硬件级失败，未解决

- 现象：`mmc1: error -110 whilst initialising SDIO card`，`/sys/bus/sdio/devices/` 为空，
  无 `wlan0`；同槽插 TF 卡可正常识别（29.1GB SDHC）。
- 已排除：驱动（bcmdhd 已内置）、固件已就位、信号电压 1.80V、`vccio_sd=1800000`、
  `vcc3v3_sd` 已使能、去掉了 `mmc-pwrseq`、改 in-band 中断、bus-width 4→1、频率 50MHz→1MHz。
- 判定：**硬件层问题**，优先查 `WL_REG_ON` 是否被拉高到 1.8V、模组 `VDD_1V8` 供电、
  金手指接触、32.768kHz 时钟。
- 详情见：`模块/Linux/AP6275S/`（README、集成计划、SDIO 检测命令）。

---

## 八、失败排查顺序（可复用 checklist）

```
1. systemctl is-active / is-enabled wifi-ap
2. journalctl -u wifi-ap -n 50            → 有没有 "AP-ENABLED"？没有则看报错行
3. pgrep -a hostapd; pgrep -a dnsmasq     → 进程在不在
4. ls /sys/class/net/wlp1s0               → 接口在不在（驱动/固件是否就绪）
5. nmcli -t -f DEVICE,STATE dev status | grep wlp1s0
                                          → 必须是 unmanaged，disconnected 就是没生效
6. 前台跑 hostapd 8s                      → 区分"配置问题"还是"驱动状态问题"
7. 主机/手机实际连接 + 看 DHCP              → 唯一可靠的端到端验证
```

> 记住三条：**等接口**、**NM 设 unmanaged 并 restart**、**以 AP-ENABLED + 实连为准（不看 tx_packets、不信单次扫描）**。

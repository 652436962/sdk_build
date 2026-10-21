# RK3568 高通 PCIe 无线网卡（ath10k）内核配置指南

**平台**：飞凌 OK3568-C（瑞芯微 RK3568，Buildroot SDK）
**内核**：Linux 5.10.160（`RK_KERNEL_CFG=OK3568-C-linux_defconfig`）
**适用网卡**：高通 Atheros 802.11ac 系列 PCIe 无线网卡（QCA6174 / QCA9377 / QCA988x 等，使用内核自带 ath10k 驱动）

> **实测网卡**：**QCA9880 / QCA988X hw2.0**（PCI ID `168c:003c`，subsys `1dac:0257`）。
> 2026-10-10 在该板实测：按本文配置内核后，驱动加载正常，**唯一缺的是固件**（见第五节），
> 补上 `QCA988X/hw2.0` 固件后 `wlp1s0` 正常出现并成功扫描到 AP。详见第九节实测记录。
> **串口控制台波特率为 115200**（非 1500000）。

---

## 一、背景与依赖关系

ath10k 是内核自带的高通 802.11ac 无线驱动，通过 **PCIe** 总线工作。要正常使用，需要把下面 4 个驱动配成**模块**（`=m`），并按依赖顺序加载：

```
cfg80211.ko   →   mac80211.ko   →   ath10k_core.ko   →   ath10k_pci.ko
（无线配置API）    （802.11协议栈）    （ath10k 核心）      （PCI 总线，绑定实际硬件）
```

- `ATH10K` 依赖 `MAC80211` 与 `HAS_DMA`；`ATH10K_PCI` 依赖 `ATH10K` 与 `PCI`。
- `ATH_COMMON`、`ATH10K_CE`、`CRC32`、`FW_LOADER` 等由 `ATH10K` 自动 `select`，**无需手动配置**。
- RK3568 内核已默认开启 PCIe 控制器（`CONFIG_PCI=y`、`CONFIG_PCIE_ROCKCHIP_HOST=y`、`CONFIG_PCIE_DW_ROCKCHIP=y`），**无需额外配置**。

---

## 二、需要开启的配置项（配置成模块 =m）

在 `menuconfig` 中按键说明：`*` = 内建（`=y`），`M` = 模块（`=m`），空白 = 不编译（`=n`）。

| 菜单路径 | 菜单项 | 配置符号 | 目标值 |
|----------|--------|----------|--------|
| Networking support → Wireless | cfg80211 - wireless configuration API | `CONFIG_CFG80211` | `m` |
| Networking support → Wireless | Generic IEEE 802.11 Networking Stack (mac80211) | `CONFIG_MAC80211` | `m` |
| Device Drivers → Network device support → Wireless LAN | Wireless LAN（菜单总开关） | `CONFIG_WLAN` | `y`（默认 y） |
| … → Wireless LAN | Atheros/Qualcomm devices（厂商菜单） | `CONFIG_WLAN_VENDOR_ATH` | `y`（默认 y） |
| … → Atheros/Qualcomm devices | Atheros 802.11ac wireless cards support | `CONFIG_ATH10K` | `m` |
| … → Atheros/Qualcomm devices | Atheros ath10k PCI support | `CONFIG_ATH10K_PCI` | `m` |

> **菜单名说明**：不同内核版本菜单名有差异。
> - 题目里的 **"Qualcomm Atheros 802.11ac wireless networking support"** / **"Atheros Wireless Cards"**，在本内核（5.10.160）中即厂商菜单 **"Atheros/Qualcomm devices"**（`WLAN_VENDOR_ATH`）。
> - **"Atheros 802.11ac wireless cards support"** 就是 `ATH10K`；其下 **"Atheros ath10k PCI support"** 就是 `ATH10K_PCI`。
> - 部分内核里 `ath10k` 会多一层同名子菜单，点进去即是 `ATH10K_PCI`。

---

## 三、配置方法

### 方式一：图形化菜单（推荐，自动回写 defconfig）
在容器内的 RK3568 SDK 根目录执行：
```bash
cd /workspace/OK3568-linux-source
./build.sh kernel-config
```
按第二节的菜单路径逐项设置为 `M`（空格键切换），保存退出。
该命令内部会依次执行 `make menuconfig` → `make savedefconfig` → `mv kernel/defconfig arch/arm64/configs/OK3568-C-linux_defconfig`，即**自动把配置回写到 defconfig**。

### 方式二：直接编辑 defconfig（无交互 / 可脚本化）
编辑 `kernel/arch/arm64/configs/OK3568-C-linux_defconfig`，加入：
```
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_ATH10K=m
CONFIG_ATH10K_PCI=m
```
> `CONFIG_WLAN`、`CONFIG_WLAN_VENDOR_ATH` 默认即为 `y`，一般无需显式添加；如需确定性也可一并写入 `CONFIG_WLAN=y`、`CONFIG_WLAN_VENDOR_ATH=y`。

然后在容器内执行 `./build.sh kernel`（会自动应用该 defconfig）。

---

## 四、重新编译并打包

```bash
cd /workspace/OK3568-linux-source

./build.sh kernel      # 编译内核 + 模块，并把 .ko 安装到 buildroot target
./build.sh rootfs      # 重新打包 rootfs.img（把新模块打进根文件系统）
./build.sh updateimg   # 重新生成 rockdev/update.img
```

或一步全量编译（含以上全部）：
```bash
./build.sh
```

> 模块安装位置（编译期）：`buildroot/output/OK3568/target/usr/lib/modules/5.10.160/`
> 打包后板端位置：`/usr/lib/modules/5.10.160/`

---

## 五、固件（firmware）准备（关键）

ath10k 必须加载**对应网卡的固件**才能真正工作。若缺固件，模块能加载但**不会创建无线网卡**，`dmesg` 报类似：
```
ath10k_pci 0000:01:00.0: Direct firmware load for ath10k/QCA6174/hw3.0/firmware-6.bin failed with error -2
```

请把对应型号固件放到板端 `/lib/firmware/ath10k/<型号>/<hw版本>/`。**目录名必须与 `dmesg` 报错里的路径完全一致**，否则驱动找不到。

常见型号对应文件：

| 网卡型号 | 板端目录 | 必需文件 |
|----------|----------|----------|
| QCA9880 / QCA988X hw2.0 | `/lib/firmware/ath10k/QCA988X/hw2.0/` | `firmware-5.bin`、`board.bin` |
| QCA6174 hw3.0 | `/lib/firmware/ath10k/QCA6174/hw3.0/` | `firmware-6.bin`、`board.bin` |

> 实测的 QCA988X hw2.0 用的是 `firmware-5.bin`（firmware ver `10.2.4-1.0-00047 api 5`）。
> 若 `dmesg` 提示找不到，驱动会从 API 6 往 2 依次尝试 `firmware-N.bin`，按报错目录放对应版本即可。
> 已知 5.10 内核里 `firmware-4.bin` 一般用不到，`firmware-5.bin` 即可。

固件来源：
- 内核官方固件仓库 linux-firmware：
  `git clone https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git`，取其中 `ath10k/` 目录。
- 或随无线网卡 / 开发板厂商提供的固件包。
- **注意**：发行版（如 Ubuntu）安装的 linux-firmware 里文件是 **`.zst` 压缩**的（`/lib/firmware/ath10k/.../*.bin.zst`），
  板端内核通常**不支持**直接加载 `.zst`，必须先解压：
  ```bash
  zstd -d firmware-5.bin.zst -o firmware-5.bin
  zstd -d board.bin.zst     -o board.bin
  ```

### 持久化：放入 buildroot overlay（推荐）
本 SDK 的实际 overlay 路径为 **`buildroot/board/forlinx/ok3568/fs-overlay/`**
（已在 `buildroot/configs/OK3568_defconfig` 的 `BR2_ROOTFS_OVERLAY` 中）。放成品文件：
```
buildroot/board/forlinx/ok3568/fs-overlay/lib/firmware/ath10k/QCA988X/hw2.0/
    ├── firmware-5.bin
    └── board.bin
```
然后重新打包根文件系统：
```bash
cd /workspace/OK3568-linux-source
./build.sh rootfs
./build.sh updateimg
```
> overlay 内容会随 rootfs 打进镜像，重新烧录后依然有效。

### 免重新烧录的快速验证（串口 ZMODEM 上传）
只是想先验证驱动、不想重刷镜像时，可用板端自带的 `rz` 直接上传（板端需有 `lrzsz`）：
1. 板端：`mkdir -p /lib/firmware/ath10k/QCA988X/hw2.0 && cd /lib/firmware/ath10k/QCA988X/hw2.0 && rz -y -b`
2. 主机（同一串口）：`sz -b firmware-5.bin`（`cd` 到文件所在目录，发送文件名即目标名）
3. 校验：板端 `md5sum *`，与主机一致即可
4. 重新探测驱动：`modprobe -r ath10k_pci && modprobe ath10k_pci`，再看 `dmesg`/`ip link`

> **坑**：`rz` 在 ZMODEM 模式下**不能带文件名参数**，`rz -y -b /path/file.bin` 会报
> `rz: garbage on commandline`。正确做法是先 `cd` 到目标目录再运行裸 `rz`，文件名由发送端决定。

---

## 六、验证

**编译侧（容器内）**
```bash
# 1) 确认内核配置已生效
grep -E "CONFIG_(CFG80211|MAC80211|ATH10K)" kernel/.config

# 2) 确认模块已生成 / 安装到 rootfs
find buildroot/output/OK3568/target/usr/lib/modules/5.10.160 \
     \( -name "*ath10k*" -o -name "mac80211.ko" -o -name "cfg80211.ko" \)
```

**板端**
```bash
lsmod | grep -E "ath10k|mac80211|cfg80211"      # 驱动已加载
lspci -nn                                       # 能看到无线网卡 168c:xxxx
ls /sys/bus/pci/devices/                         # 或直接看 PCI 设备列表
dmesg | grep -i ath10k                          # 无 firmware failed 即正常
ip link                                         # 出现无线网卡（wlp1s0 或 wlan0）
```

> **说明（实测）**：
> - 本内核把 `cfg80211`、`mac80211` 编成了**内建 `=y`**（`kernel/.config`），因此 `lsmod` 里**只**会看到
>   `ath` / `ath10k_core` / `ath10k_pci`，看不到 cfg80211/mac80211，属正常，不是没加载。
> - 接口名可能被 systemd 的 predictable naming 由 `wlan0` 重命名为 **`wlp1s0`**（`dmesg` 里有
>   `wlp1s0: renamed from wlan0`），用 `ip link` 以实际名字为准。
> - 加载成功的 `dmesg` 特征（QCA988X hw2.0）：
>   ```
>   ath10k_pci 0000:01:00.0: qca988x hw2.0 target ... chip_id ...
>   ath10k_pci 0000:01:00.0: firmware ver 10.2.4-1.0-00047 api 5 ... crc32 ...
>   ath10k_pci 0000:01:00.0: board_file api 1 ... crc32 ...
>   ath10k_pci 0000:01:00.0 wlp1s0: renamed from wlan0
>   ```
> - 扫描验证：`ip link set wlp1s0 up && iw dev wlp1s0 scan | grep -E 'SSID:|signal:|freq:'`
>   （`wlp1s0` 处于 `NO-CARRIER` 未关联状态是正常的）

手动加载顺序（未自动加载时）：
```bash
modprobe cfg80211
modprobe mac80211
modprobe ath10k_core
modprobe ath10k_pci
```

---

## 七、常见问题

| 现象 | 原因 / 解决 |
|------|-------------|
| `dmesg` 报 `Direct firmware load for ath10k/... failed` | 缺固件，见第五节 |
| 板端 `/lib/firmware/ath10k/` 目录不存在 | 固件从未打包进去；按第五节放入 overlay 或串口上传 |
| 主机 linux-firmware 里是 `*.bin.zst` | 发行版压缩包，内核不认；先 `zstd -d` 解出 `.bin` 再放到板端 |
| `lsmod` 里看不到 `mac80211`/`cfg80211` | 编译选项是 `=y`（内建）而非 `=m`；属正常，不影响使用 |
| `rz: garbage on commandline` | ZMODEM 模式下 `rz` 不能带文件名参数；先 `cd` 到目标目录再运行裸 `rz` |
| `lspci` 看不到网卡 | PCIe 链路问题：检查供电/时钟/reset GPIO、设备树 PCIe 节点；用 `dmesg` 查看 pcie 相关日志 |
| `modprobe ath10k_pci` 报 `Unknown symbol` | 依赖未按序加载；先 `modprobe cfg80211 mac80211 ath10k_core` |
| 菜单里找不到 ath10k 选项 | 未开启 `CONFIG_WLAN` / `CONFIG_WLAN_VENDOR_ATH`；或未先开 `CONFIG_CFG80211` / `CONFIG_MAC80211` |
| 单独编内核后 rootfs 里没有模块 | 需再执行 `./build.sh rootfs`（或全量 `./build.sh`）重新打包根文件系统 |

---

## 八、附录：配置符号速查

| 符号 | 菜单名称 | 值 | 依赖 |
|------|----------|----|------|
| `CONFIG_CFG80211` | cfg80211 - wireless configuration API | `m` | RFKILL |
| `CONFIG_MAC80211` | Generic IEEE 802.11 Networking Stack (mac80211) | `m` | CFG80211 |
| `CONFIG_WLAN` | Wireless LAN（菜单总开关） | `y` | NET |
| `CONFIG_WLAN_VENDOR_ATH` | Atheros/Qualcomm devices（厂商菜单） | `y` | — |
| `CONFIG_ATH10K` | Atheros 802.11ac wireless cards support | `m` | MAC80211 && HAS_DMA |
| `CONFIG_ATH10K_PCI` | Atheros ath10k PCI support | `m` | ATH10K && PCI |
| `CONFIG_ATH_COMMON` / `CONFIG_ATH10K_CE` | 公共 / CE 支持 | 自动 `select` | — |

**相关文件路径（容器内 `/workspace/OK3568-linux-source/`）**

| 文件 | 路径 |
|------|------|
| 内核 defconfig | `kernel/arch/arm64/configs/OK3568-C-linux_defconfig` |
| ath10k 驱动源码 | `kernel/drivers/net/wireless/ath/ath10k/` |
| 生成的完整配置 | `kernel/.config` |
| 模块安装目标 | `buildroot/output/OK3568/target/usr/lib/modules/5.10.160/` |
| 固件 overlay | `buildroot/board/forlinx/ok3568/fs-overlay/lib/firmware/ath10k/` |
| 相关 Kconfig | `net/wireless/Kconfig`（cfg80211）、`net/mac80211/Kconfig`（mac80211）、`drivers/net/wireless/ath/Kconfig`、`drivers/net/wireless/ath/ath10k/Kconfig` |

---

## 九、实测记录（2026-10-10，OK3568-C + QCA9880/QCA988X hw2.0）

**环境**
- 串口 `/dev/ttyUSB0`，波特率 **115200**，root 登录
- 内核：`Linux OK3568-buildroot 5.10.160 #3 SMP ... aarch64`
- 网卡：PCI `0000:01:00.0`，ID `168c:003c`（QCA9880 / QCA988X hw2.0），subsys `1dac:0257`

**编译侧内核配置（`kernel/arch/arm64/configs/OK3568-C-linux_defconfig`）**
```
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_WLAN_VENDOR_ATH=y
CONFIG_ATH10K=m
CONFIG_ATH10K_PCI=m
```
> 实际 `kernel/.config` 中 `CONFIG_CFG80211=y`、`CONFIG_MAC80211=y`（被并成内建），`CONFIG_ATH10K=m`。

**初始现象（缺固件）**
```
ath10k_pci 0000:01:00.0: enabling device (0000 -> 0002)
ath10k_pci 0000:01:00.0: pci irq msi oper_irq_mode 2 irq_mode 0 reset_mode 0
ath10k_pci 0000:01:00.0: Failed to find firmware-N.bin (N between 2 and 6) from ath10k/QCA988X/hw2.0: -2
ath10k_pci 0000:01:00.0: could not fetch firmware files (-2)
ath10k_pci 0000:01:00.0: could not probe fw (-2)
```
- `lsmod`：`ath10k_pci` / `ath10k_core` / `ath` 均加载，但 `ip link` **没有**无线接口。
- 板端 `/lib/firmware/ath10k/` **不存在**。

**补固件（串口 ZMODEM 运行时上传，免重刷）**
```
# 主机解压
zstd -d firmware-5.bin.zst -o firmware-5.bin      # 249044 B
zstd -d board.bin.zst     -o board.bin            # 2116 B
# 板端  mkdir -p /lib/firmware/ath10k/QCA988X/hw2.0 && cd ... && rz -y -b
# 主机  sz -b firmware-5.bin ; sz -b board.bin
# 校验（两端 md5 一致）
ab36ef267d15cfc02317ceeb38e8f548  board.bin
adc9ed271caf0ed49004373767f4fe14  firmware-5.bin
```

**重新探测后（成功）**
```
ath10k_pci 0000:01:00.0: qca988x hw2.0 target 0x4100016c chip_id 0x043222ff sub 1dac:0257
ath10k_pci 0000:01:00.0: firmware ver 10.2.4-1.0-00047 api 5 features no-p2p,raw-mode,mfp,allows-mesh-bcast crc32 35bd9258
ath10k_pci 0000:01:00.0: board_file api 1 bmi_id N/A crc32 bebc7c08
ath10k_pci 0000:01:00.0: htt-ver 2.1 wmi-op 5 htt-op 2 cal otp max-sta 128 raw 0 hwcrypto 1
ath10k_pci 0000:01:00.0 wlp1s0: renamed from wlan0
```
`ip link` 出现 `wlp1s0`；`iw dev wlp1s0 scan` 成功扫到多个 AP（含 2.4G/5G 的 `TP-LINK_C77A`，5G 信号 -48dBm）。

**结论**：编译配置正确；只要补上 `QCA988X/hw2.0` 固件即可正常工作。该固件需持久化进 rootfs（第五节），
否则重新烧录后仍需重新上传。

---

## 十、无线工作模式（STA 客户端 / AP 热点）

前提：驱动 + 固件已就绪，接口名为 **`wlp1s0`**（见第六节）。板端已随 rootfs 提供
`iw`、`wpa_supplicant`、`hostapd`、`dnsmasq`、`udhcpc`。同一块网卡**同一时刻只能处于一种主模式**，
切换前先 `ip link set wlp1s0 down`。

### 10.1 查看 / 切换模式
```bash
iw dev wlp1s0 info                 # 看 type: managed(=STA) 还是 AP
ip link set wlp1s0 down
iw dev wlp1s0 set type managed     # 切到 STA
# 或
iw dev wlp1s0 set type __ap        # 切到 AP
ip link set wlp1s0 up
```

### 10.2 STA 模式（作为客户端连路由器）
生成配置（二选一）：
```bash
# 方式一：手写
cat > /etc/wpa_supplicant.conf <<'EOF'
ctrl_interface=/var/run/wpa_supplicant
update_config=1
country=CN

network={
    ssid="你的SSID"
    psk="你的密码"
}
EOF

# 方式二：由明文密码生成（会同时保留明文 psk，可删掉 #psk 那行）
wpa_passphrase "你的SSID" "你的密码" > /etc/wpa_supplicant.conf
```

连接并获取 IP：
```bash
ip link set wlp1s0 down
iw dev wlp1s0 set type managed
ip link set wlp1s0 up
wpa_supplicant -B -i wlp1s0 -c /etc/wpa_supplicant.conf -D nl80211
sleep 3
iw dev wlp1s0 link                 # 看是否 assoc 到 AP、信号
udhcpc -i wlp1s0 -q -n            # 获取 IP（BusyBox）
ip addr show wlp1s0
```
常用排查：`wpa_cli -i wlp1s0 status`、`dmesg | grep -i ath10k`。
停止：`killall wpa_supplicant`。

### 10.3 AP 模式（做热点）
以下即本次实测所用配置（SSID `test` / 密码 `test123456`）。

**`/etc/hostapd-lechi.conf`**
```
interface=wlp1s0
driver=nl80211
ssid=test
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1
auth_algs=1
wpa=2
wpa_passphrase=test123456
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_pairwise=CCMP
```
> - `hw_mode=g` 为 2.4G（channel 1-11，免 DFS）；要 5G 改 `hw_mode=a` 并选非 DFS 信道。
> - 想用 `hostapd_cli` 管理，再加 `ctrl_interface=/var/run/hostapd`。
> - `driver=nl80211`（mac80211 通用驱动）必填。

**`/etc/dnsmasq-lechi.conf`**（给客户端分配 IP）
```
interface=wlp1s0
bind-interfaces
except-interface=lo
dhcp-range=172.31.100.100,172.31.100.200,255.255.0.0,12h
dhcp-option=3,172.31.100.1
dhcp-option=6,172.31.100.1
```
> 若系统里已有别的 dnsmasq 占用 53 端口，加一行 `port=0` 只做 DHCP（不做 DNS）。

启动：
```bash
ip link set wlp1s0 down
iw dev wlp1s0 set type __ap
ip link set wlp1s0 up
ip addr add 172.31.100.1/16 dev wlp1s0
hostapd -B /etc/hostapd-lechi.conf
dnsmasq -C /etc/dnsmasq-lechi.conf
```
验证：
```bash
iw dev wlp1s0 info                 # type AP, ssid test, channel 6 (2437 MHz)
netstat -anu | grep -E ':53|:67'   # dnsmasq 监听中
```
手机/电脑搜索 `test`，输入密码 `test123456`，可获取 `172.31.100.100~200` 的地址。

停止：
```bash
killall hostapd dnsmasq
```
> 实测结果：hostapd 进入 `AP-ENABLED`，`iw` 显示 `type AP / ssid test / channel 6`，
> dnsmasq 监听 `172.31.100.1:53` 与 `0.0.0.0:67`。

### 10.4 共享上网（NAT，可选，需要上行）
> `S99wifi-ap` 脚本**只开热点、不做 NAT 转发**（见 10.5）。要让 AP 客户端上外网时，再手动执行本节。
AP 客户端要能上外网，需要一块已联网的上行口（本例为 **eth0** 接网线）。

**1) 上行口联网（DHCP）**
```bash
ip link set eth0 up
cat /sys/class/net/eth0/carrier          # 1 = 网线已插好
ethtool eth0 | grep -i 'link detected'   # yes
udhcpc -i eth0 -b                        # 拿 IP 并后台续租
sleep 5
ip -br addr show eth0                    # 例：192.168.1.100/24
ip route | grep default                  # 例：default via 192.168.1.1 dev eth0
cat /etc/resolv.conf                     # udhcpc 写入的上游 DNS
```

**2) 开转发 + NAT**
```bash
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i wlp1s0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o wlp1s0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```
> 若系统里已有别的 dnsmasq 占用 53 端口，加一行 `port=0` 只做 DHCP（不做 DNS）。

**3) 让 dnsmasq 拿到上游 DNS**（若 dnsmasq 在 eth0 联网前就已启动）
```bash
killall -HUP dnsmasq        # 或改为重启 dnsmasq
```

**验证**
```bash
cat /proc/sys/net/ipv4/ip_forward                 # 1
iptables -t nat -L POSTROUTING -n -v              # 有 MASQUERADE ... out eth0
iptables -L FORWARD -n -v                         # 两条 ACCEPT
netstat -anu | grep -E ':(53|67)'                 # dnsmasq 在监听
nslookup www.baidu.com 172.31.100.1               # 经 AP 的 DNS 能解析
```
> 实测（本板 + 网线）：eth0 得 `192.168.1.100`、`ping 8.8.8.8` 通、
> `www.baidu.com` 解析到 `183.2.172.177`；AP 侧 `172.31.100.1:53` 解析正常。
> 客户端连上后自动获取 `172.31.100.100~200` 的 IP，经 NAT 上网。

### 10.5 一键脚本 / 开机自启
本目录已提供脚本 **`S99wifi-ap`**（**只开 WiFi 热点：hostapd + dnsmasq；不含 NAT 转发**，支持 `start|stop|restart|status|clients`）。
上传到板端并加执行权限：
```bash
# 主机：串口 ZMODEM 上传（见第五节方法）
#   板端  cd /etc/init.d && rz -y -b
#   主机  sz -b S99wifi-ap
chmod +x /etc/init.d/S99wifi-ap

# 手动测试
/etc/init.d/S99wifi-ap start      # 起热点(hostapd + dnsmasq)
/etc/init.d/S99wifi-ap status     # addr/proc/ap/clients
/etc/init.d/S99wifi-ap clients    # 只看已连客户端(MAC/信号/IP)
/etc/init.d/S99wifi-ap restart    # 重启
/etc/init.d/S99wifi-ap stop       # 关热点
```
以 `S99` 命名放在 `/etc/init.d/`，开机（runlevel 默认）会自动执行 `start`。
> 需要 AP 客户端上外网时，另行执行 **10.4** 的 NAT 步骤（或自行把它加回脚本）。

脚本内部逻辑（等价于 10.3，**不含 10.4 的 NAT/转发**）：
```sh
#!/bin/sh
WIFI=wlp1s0; AP_CIDR=172.31.100.1/16
HOSTAPD_CONF=/etc/hostapd-lechi.conf; DNSMASQ_CONF=/etc/dnsmasq-lechi.conf
case "$1" in
  start)
    iw reg set CN 2>/dev/null
    killall hostapd dnsmasq 2>/dev/null; sleep 1
    ip link set $WIFI down; iw dev $WIFI set type __ap; ip link set $WIFI up
    ip addr flush dev $WIFI 2>/dev/null
    ip addr add $AP_CIDR dev $WIFI 2>/dev/null
    hostapd -B $HOSTAPD_CONF
    dnsmasq -C $DNSMASQ_CONF
    ;;
  stop)
    killall hostapd dnsmasq 2>/dev/null
    ip link set $WIFI down 2>/dev/null
    ;;
esac
```
> 实测：`S99wifi-ap restart` 后热点 `AP-ENABLED`；`status` 显示 hostapd/dnsmasq 的 PID、`type AP`、`ssid test`、ch6，
> 且 **`ip_forward=0`、无 MASQUERADE 规则**（转发已去除）。
> 注意本 BusyBox 的 `ps` 默认不显示无 tty 的守护进程，脚本用 `pidof` 判活。

> **持久化提示**：`/etc` 下这些配置在当前板子上可写，但重刷镜像后会丢失。
> 要固化，请把它们放进 buildroot overlay：`buildroot/board/forlinx/ok3568/fs-overlay/etc/`
> （连同第五节固件头一起重新打包 `./build.sh rootfs && ./build.sh updateimg`）。

### 10.6 查看已连接的客户端（含 IP）
AP 起来后，查看当前连上了哪些设备。

**方式零：脚本一键（最省事，见 10.5）**
```bash
/etc/init.d/S99wifi-ap clients
```
输出把「关联的 MAC / 信号 / IP」对齐列出，并附带 DHCP 租约与 ARP 表。示例（静态 IP 客户端）：
```
== clients (MAC / signal / IP) ==
  a4:cb:8f:c8:d9:8c  signal=-73      IP=172.31.3.2
  fc:01:2c:d7:e7:5c  signal=-73      IP=172.31.1.6
  ...
-- DHCP leases (dynamic) --  (none)
```
> **重点**：`iw station dump` 只有 MAC、**没有 IP**；要拿 IP 必须查 **ARP 表**（静态 IP 客户端也在里面，
> 通信一次后才有记录）。上面脚本已把二者按 MAC 关联起来。

**方式一：`iw station dump`（关联层，无 IP）**
```bash
iw dev wlp1s0 station dump                                   # 所有关联客户端详情
iw dev wlp1s0 station dump | grep -E '^Station|signal:|bitrate:|connected time'
iw dev wlp1s0 station dump | grep -c '^Station'              # 只统计客户端数量
```
每个 `Station <MAC>` 段包含信号强度、收发速率、字节数、在线时长等。

**方式二：`hostapd_cli`（需要 hostapd 配置里有 `ctrl_interface`）**
```bash
# 前提：/etc/hostapd-lechi.conf 里加一行 ctrl_interface=/var/run/hostapd
#       然后 killall hostapd && hostapd -B /etc/hostapd-lechi.conf 重启
hostapd_cli -i wlp1s0 status        # AP 状态
hostapd_cli -i wlp1s0 all_sta       # 列出所有客户端 MAC
hostapd_cli -i wlp1s0 sta <MAC>     # 指定客户端详情
```
> 本仓库提供的 `hostapd-lechi.conf` 默认没写 `ctrl_interface`，所以 `hostapd_cli` 会连不上；
> 需要该功能时按上面加一行并重启 hostapd。

**方式三：DHCP 租约（dnsmasq 分配过 IP 的）**
```bash
cat /var/lib/misc/dnsmasq.leases     # 格式：到期时间 MAC 分配的IP 主机名 客户端ID
```
> 客户端用**静态 IP** 时这里为空，属正常，改看下面 ARP。

**方式四：ARP 表（拿 IP 的关键，静态/动态都在此）**
```bash
cat /proc/net/arp
```

> `iw station dump` 反映 **802.11 层已关联**的客户端；IP 要从 **ARP 表**看（`incomplete` = 尚未通信）；
> dnsmasq 租约只对动态获取 IP 的客户端有效。三者交叉对照即可。

# OK3562 Ubuntu 适配高通 PCIe WiFi（QCA9880 / ath10k）

> **平台**：飞凌 OK3562-C（瑞芯微 RK3562），Ubuntu 22.04 根文件系统（`ubuntu/jammy-rootfs.img`），内核 **5.10.198**
> **网卡**：高通 Atheros **QCA9880 / QCA988X hw2.0**（PCIe，ID `168c:003c`）
> **驱动**：内核自带 **ath10k**（不额外提供源码，只需开配置 + 模块 + 固件）
> **SDK**：`ok3562_sdk/OK3562-linux-source`（容器 `ok3562-sdk`）

---

## 一、改动总览

| 项 | 内容 |
|----|------|
| 内核 defconfig | `kernel-5.10/arch/arm64/configs/OK3562_Linux_defconfig`：加 `CONFIG_ATH10K=m`、`CONFIG_ATH10K_PCI=m` |
| 内核模块 | `ath.ko`、`ath10k_core.ko`、`ath10k_pci.ko` → rootfs `/lib/modules/5.10.198/...` 并 `depmod` |
| 固件 | QCA988X hw2.0 的 `firmware-5.bin`、`board.bin` → rootfs `/lib/firmware/ath10k/QCA988X/hw2.0/` |
| 分区表 | `parameter-ubuntu-fit.txt`：rootfs 由 12.7G **缩小到 5.53G**，解决 "partition larger than flash" |
| 产物 | `rockdev/update.img`（完整烧录镜像） |

> 说明：本 SDK **实际使用的内核是 `kernel-5.10/`**，不是 `kernel/`；板级配置为
> `forlinx_ok3562_ubuntu22_defconfig`（`RK_KERNEL_CFG="OK3562_Linux_defconfig"`）。

---

## 二、内核配置（ath10k）

`kernel-5.10/arch/arm64/configs/OK3562_Linux_defconfig` 追加：

```
CONFIG_ATH10K=m
CONFIG_ATH10K_PCI=m
```

依赖项（本 SDK 默认已满足，无需改）：
```
CONFIG_CFG80211=y
CONFIG_MAC80211=y
CONFIG_WLAN=y
CONFIG_WLAN_VENDOR_ATH=y
CONFIG_PCI=y / CONFIG_PCIE_ROCKCHIP_HOST=y / CONFIG_PCIE_DW_ROCKCHIP=y
```

编译：
```bash
cd /workspace/OK3562-linux-source
./build.sh kernel
```
成功后会生成 `ath.ko`、`ath10k_core.ko`、`ath10k_pci.ko` 和 `kernel-5.10/boot.img`。

---

## 三、内核模块安装到 Ubuntu rootfs

`ath10k` 是 `=m`（模块），必须放进 rootfs 并被 `modprobe/udev` 找到。

```bash
K=kernel-5.10
M=<rootfs>/lib/modules/5.10.198/kernel/drivers/net/wireless/ath
mkdir -p $M/ath10k
cp $K/drivers/net/wireless/ath/ath.ko $M/
cp $K/drivers/net/wireless/ath/ath10k/ath10k_core.ko $K/drivers/net/wireless/ath/ath10k/ath10k_pci.ko $M/ath10k/
depmod -b <rootfs> 5.10.198
```

> 本 SDK 的 rootfs 直接使用 `ubuntu/jammy-rootfs.img`（`output/firmware/rootfs.img` 软链它），
> 把它 `mount -o loop` 后拷贝即可。
> `ath10k_pci.ko` 带 PCI alias，插卡后 **udev 会自动 modprobe**（前提 `depmod` 已更新）。

---

## 四、固件

ath10k 必须有对应固件，否则能加载但不创建网卡（`dmesg` 报 `Direct firmware load ... failed`）。

板端路径：
```
/lib/firmware/ath10k/QCA988X/hw2.0/
    ├── firmware-5.bin
    └── board.bin
```

来源：内核官方 **linux-firmware** 的 `ath10k/QCA988X/hw2.0/`。
> Ubuntu 的 linux-firmware 里是 **`.zst` 压缩**，板端内核不认，需先解压：
> ```bash
> zstd -d firmware-5.bin.zst -o firmware-5.bin
> zstd -d board.bin.zst     -o board.bin
> ```

放入 rootfs 后随镜像打包（见第六节）。

---

## 五、分区表（关键坑：partition larger than flash）

默认 `device/forlinx/.chips/ok3562/parameter-ubuntu-fit.txt` 把 **rootfs 开到 12.7GB**，
总分区需 ≥13.1GB，在小容量 eMMC 上会报：

```
Note: Definition of partition in the firmware is larger than flash
```

改为"刚好容纳 rootfs.img"（对 8GB / 16GB eMMC 都安全，`userdata` 自动 grow）：

```
CMDLINE: mtdparts=:0x00002000@0x00004000(uboot),0x00002000@0x00006000(misc),0x00020000@0x00008000(boot),0x00040000@0x00028000(recovery),0x00010000@0x00068000(backup),0x00B10000@0x00078000(rootfs),0x00040000@0x00B88000(oem),0x00002000@0x00BC8000(amp),-@0x00BCA000(userdata:grow)
```

| 分区 | 起始 | 大小 |
|------|------|------|
| rootfs | `0x00078000` | `0x00B10000`（5.53 GiB） |
| oem | `0x00B88000` | `0x00040000` |
| amp | `0x00BC8000` | `0x00002000` |
| userdata | `0x00BCA000` | grow |

> 最小总占用 ≈ **5.89 GiB**；8GB eMMC 下 userdata ≈ 2.1GiB。

---

## 六、编译与打包

> ⚠️ 必须以 **与 SDK 属主同 UID 的非 root 用户**（如 `builduser`）执行 `./build.sh`，否则内核模块安装报 `Permission denied`。

```bash
cd /workspace/OK3562-linux-source

./build.sh defconfig:forlinx_ok3562_ubuntu22_defconfig   # 选板级配置（ubuntu）
./build.sh kernel                                         # 编内核 + ath10k 模块
./build.sh updateimg                                      # 重新打包 update.img
```

产物：
```
rockdev/update.img   （软链到 output/update/Image/update.img）
rockdev/boot.img     （软链到 kernel-5.10/boot.img）
```
> 单独编 kernel 后 **update.img 不会自动更新**，必须再执行 `./build.sh updateimg`。

---

## 七、烧录与验证

用 RKDevTool / `upgrade_tool` 加载 `update.img` 整包烧录（或分步烧 `boot.img`）。

板端验证：
```sh
lspci -nn | grep -i 168c                 # 应看到 168c:003c
lsmod | grep -E "ath10k|^ath"            # ath / ath10k_core / ath10k_pci
dmesg | grep -i ath10k                    # 无 firmware failed
ip link | grep -E "wlan|wlp"             # 出现 wlan0 / wlpXs0
```

成功日志特征：
```
ath10k_pci 0000:01:00.0: qca988x hw2.0 target ... chip_id ...
ath10k_pci 0000:01:00.0: firmware ver 10.2.4-1.0-00047 api 5 ... crc32 ...
ath10k_pci 0000:01:00.0: board_file api 1 ...
ath10k_pci 0000:01:00.0 wlp1s0: renamed from wlan0
```

未自动加载时手动：
```sh
modprobe ath10k_core
modprobe ath10k_pci
```

---

## 八、回退

| 项 | 回退 |
|----|------|
| 内核配置 | 删除 defconfig 里的 `CONFIG_ATH10K=m`、`CONFIG_ATH10K_PCI=m`，重编 |
| 模块 | 删除 rootfs 里对应 `.ko`，重跑 `depmod` |
| 固件 | 删除 `/lib/firmware/ath10k/QCA988X/` |
| 分区 | `cp parameter-ubuntu-fit.txt.bak-12g parameter-ubuntu-fit.txt` |

---

## 九、相关路径速查（容器 `/workspace/OK3562-linux-source/`）

| 内容 | 路径 |
|------|------|
| 内核 defconfig | `kernel-5.10/arch/arm64/configs/OK3562_Linux_defconfig` |
| ath10k 源码 | `kernel-5.10/drivers/net/wireless/ath/ath10k/` |
| 实际内核 | `kernel-5.10/`（不是 `kernel/`） |
| 板级配置 | `device/forlinx/ok3562/forlinx_ok3562_ubuntu22_defconfig` |
| Ubuntu rootfs | `ubuntu/jammy-rootfs.img` |
| 分区参数 | `device/forlinx/.chips/ok3562/parameter-ubuntu-fit.txt` |
| 固件目标 | `<rootfs>/lib/firmware/ath10k/QCA988X/hw2.0/` |
| 模块目标 | `<rootfs>/lib/modules/5.10.198/kernel/drivers/net/wireless/ath/` |

---

## 十、热点与应用

驱动起来后，把 `wlp1s0` 做成开机自启的 WiFi 热点（SSID `test`），并让 `tcpserver` 随系统启动：

- 配置与踩坑说明：[wifi-ap与tcpserver开机自启.md](./wifi-ap与tcpserver开机自启.md)
- 失败排查全过程（含误判修正）：[wifi-ap失败排查记录.md](./wifi-ap失败排查记录.md)
- 可直接复用的配置原件：[files/](./files/)

# OpenRockCLI 瑞芯微烧录工具

**OpenRockCLI** 是一款开源的命令行 + 轻量 TUI（终端交互界面）固件烧录工具，专为瑞芯微（Rockchip）SoC 设计。它保留了 Rockchip Maskrom/Loader 底层命令，并增加了与 OpenixCLI 兼容的工作流，用于扫描设备和烧录 Rockchip `update.img` 固件包。

**项目地址**：https://github.com/dshanpi/openrockcli

---

## 功能特性

| 功能 | 说明 |
|------|------|
| 设备扫描 | 显示 USB 总线/端口、模式、VID/PID 和芯片名称 |
| OpenixCLI 兼容命令 | `scan`、`flash`、`tui` |
| 固件辅助命令 | `devices`、`inspect`、`unpack` |
| 固件烧录 | 通过 SDK 自带的 `upgrade_tool` 烧录 Rockchip `update.img` |
| 固件信息查看 | 查看固件信息与解包 |
| 底层命令 | 保留原始 Maskrom、存储、Flash、OTP、厂商存储等 Rockusb 底层命令 |
| 多平台 | Linux / Windows（Windows 仅支持 USB 扫描与底层 libusb 命令） |

---

## 架构

```
User / CI / Script
        │
        ▼
openrockcli CLI（命令解析与 TUI）
        │
        ├──▶ Rockchip 固件后端
        │         ├── upgrade_tool（固件烧录）
        │         └── update.img 检查 / 解包
        │
        └──▶ 底层 Rockusb 命令（libusb-1.0）
```

- OpenixCLI 风格命令（`scan`、`flash`、`devices`、`inspect`、`unpack`、`tui`）位于 CLI 层；
- 固件包烧录在安全的前提下委托给 Rockchip `upgrade_tool`；
- 原始底层 Rockusb 命令直接使用 libusb。

---

## 源码结构

```
openrockcli/
├── .github/workflows/      GitHub Actions 构建与发布工作流
├── include/                公共与内部 C 头文件
├── payloads/               Maskrom 辅助 payload 源码
├── src/                    C 实现文件
├── 99-openrockcli.rules    Linux udev 规则
├── Makefile                Linux 原生构建
├── Makefile.win            MinGW Windows 构建
└── README.md
```

---

## 安装

### Linux 平台编译安装

OpenRockCLI 依赖 `libusb-1.0`，先安装开发库（以 Ubuntu 为例）：

```bash
sudo apt install libusb-1.0-0-dev
```

然后编译：

```bash
cd openrockcli
make
sudo make install
```

Ubuntu 用户也可以直接安装 release 提供的 `amd64` `.deb` 包：

```bash
sudo apt install ./openrockcli_*_amd64.deb
openrockcli --version
```

### Windows 平台编译

```bash
sudo apt install mingw-w64 autoconf libtool-bin

# 下载并安装 libusb
git clone https://github.com/libusb/libusb.git
cd libusb
./autogen.sh
./configure --host=x86_64-w64-mingw32 --prefix=/usr/x86_64-w64-mingw32/
make
sudo make install

# 编译 openrockcli
cd openrockcli
CROSS=x86_64-w64-mingw32- make -f Makefile.win
```

> 32 位 Windows 将 `x86_64-w64-mingw32` 换成 `i686-w64-mingw32`。Windows 构建支持 USB 扫描和底层 libusb 命令；需要调用 `upgrade_tool` 的 `update.img` 烧录流程仅在 Linux 构建中可用。

### upgrade_tool 路径设置

`flash`、`devices`、`inspect`、`unpack` 命令依赖 Rockchip `upgrade_tool`。默认从以下相对路径搜索（SDK 自带）：

```
tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool
```

可通过环境变量覆盖：

```bash
OPENROCKCLI_UPGRADE_TOOL=/path/to/upgrade_tool openrockcli devices
```

> 本 SDK 仓库中 RK3562 / RK3568 平台的 `upgrade_tool` 位于各自 SDK 源码目录的
> `tools/linux/Linux_Upgrade_Tool/` 下，可将该目录的 `upgrade_tool` 通过环境变量指定给 openrockcli 使用。

### USB 权限配置

为避免每次运行都需要 root 权限，可添加 udev 规则（Rockchip 设备 vendor ID `2207`），仓库自带了 `99-openrockcli.rules`：

```bash
# 方式一：使用仓库自带规则
sudo cp 99-openrockcli.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

# 方式二：手动添加
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0666"' | sudo tee /etc/udev/rules.d/99-rockchip.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

添加后重新插拔设备即可免 `sudo` 使用 `openrockcli`。

---

## OpenixCLI 兼容用法

### 帮助与版本

```bash
openrockcli --help
openrockcli --version
openrockcli help flash
openrockcli help tui
```

### 启动交互式 TUI

```bash
openrockcli
openrockcli tui
```

### 扫描 Rockchip USB 设备

```bash
openrockcli scan
```

输出包含 USB 总线/端口、模式、VID/PID、芯片名称。

### 通过 upgrade_tool 列出设备

```bash
openrockcli devices
```

### 查看固件包信息

```bash
openrockcli inspect update.img
```

### 解包固件包

```bash
openrockcli unpack update.img ./extracted
```

### 烧录固件

```bash
openrockcli flash update.img [options]
```

#### 烧录选项

| 选项 | 简写 | 说明 |
|------|------|------|
| `--bus` | `-b` | USB 总线选择器（见 `scan` 输出） |
| `--port` | `-P` | USB 端口选择器（见 `scan` 输出） |
| `--verify` | `-V` | 启用校验偏好设置；也可传 `true` / `false` |
| `--no-verify` | | 禁用校验偏好设置 |
| `--mode` | `-m` | `partition`、`keep_data`、`partition_erase` 或 `full_erase` |
| `--partitions` | `-p` | 逗号分隔的分区名（配合 `--mode partition`） |
| `--post-action` | `-a` | `reboot`、`poweroff` 或 `shutdown` |
| `--verbose` | `-v` | 打印所选选项 |

#### 烧录示例

```bash
openrockcli flash update.img --verbose
openrockcli flash update.img --post-action poweroff
openrockcli flash update.img --mode full_erase --verify true
openrockcli flash update.img --mode partition --partitions boot,uboot,misc,recovery
openrockcli flash update.img --mode partition --partitions rootfs,oem,userdata
```

#### 说明

- Rockchip `update.img` 烧录委托给 `upgrade_tool UF`。
- `--mode partition` 先用 `upgrade_tool EXF` 解包 `update.img`，再烧录所选条目：已知 `upgrade_tool DI` 分区用 `DI`；`rootfs`、`oem`、`userdata` 等条目通过解析 `parameter.txt` 调用 `upgrade_tool WL` 写入。
- 当前分区烧录支持：`boot`、`uboot`、`misc`、`recovery`、`kernel`、`system`、`trust`、`resource`、`rootfs`、`oem`、`userdata`。
- `poweroff` / `shutdown` 映射为 `upgrade_tool UF -noreset`（upgrade_tool 对 `update.img` 烧录没有真正的关机动作）。
- 裸扇区操作请使用下面的底层 `openrockcli flash read` / `flash write` / `flash erase` 命令。

---

## 底层命令用法

底层 Rockchip 命令仍保留在 OpenixCLI 风格入口之后：

```
usage:
    openrockcli                              - 启动交互式 TUI
    openrockcli tui                          - 启动交互式 TUI
    openrockcli scan                         - 列出已连接的 Rockchip USB 设备
    openrockcli devices                      - 通过 upgrade_tool 列出 Rockusb 设备
    openrockcli inspect <firmware.img>       - 查看 Rockchip 固件包信息
    openrockcli unpack <firmware.img> <dir>  - 解包 Rockchip 固件包
    openrockcli flash <firmware.img> [opts]  - 通过 upgrade_tool 烧录 Rockchip update.img
    openrockcli maskrom <ddr> <usbplug> [--rc4-off]    - Maskrom 模式下用 ddr 和 usbplug 初始化芯片
    openrockcli download <loader>                      - Maskrom 模式下用 loader 初始化芯片
    openrockcli upgrade <loader>                       - Loader 模式下升级 flash 中的 loader
    openrockcli ready                                  - 显示芯片是否就绪
    openrockcli version                                - 显示芯片版本
    openrockcli capability                             - 显示能力信息
    openrockcli reset [maskrom]                        - 复位芯片到 normal 或 maskrom 模式
    openrockcli dump <address> <length>                - 以 hex 格式转储内存区域
    openrockcli read <address> <length> <file>         - 读取内存到文件
    openrockcli write <address> <file>                 - 写文件到内存
    openrockcli exec <address> [dtb]                   - 调用函数地址（建议使用 extra 命令）
    openrockcli otp <length>                           - 以 hex 格式转储 OTP 内存
    openrockcli sn                                     - 读取序列号
    openrockcli sn <string>                            - 写入序列号
    openrockcli vs dump <index> <length> [type]        - 以 hex 格式转储厂商存储
    openrockcli vs read <index> <length> <file> [type] - 读取厂商存储
    openrockcli vs write <index> <file> [type]         - 写入厂商存储
    openrockcli storage                                - 读取存储介质列表
    openrockcli storage <index>                        - 切换存储介质并显示列表
    openrockcli flash                                  - 检测 Flash 并显示信息
    openrockcli flash erase <sector> <count>           - 擦除 Flash 扇区
    openrockcli flash read <sector> <count> <file>     - 读取 Flash 扇区到文件
    openrockcli flash write <sector> <file>            - 写文件到 Flash 扇区
extra:
    openrockcli extra maskrom --rc4 <on|off> [--sram <file> --delay <ms>] [--dram <file> --delay <ms>] [...]
    openrockcli extra maskrom-dump-arm32 --rc4 <on|off> --uart <register> <address> <length>
    openrockcli extra maskrom-dump-arm64 --rc4 <on|off> --uart <register> <address> <length>
    openrockcli extra maskrom-write-arm32 --rc4 <on|off> <address> <file>
    openrockcli extra maskrom-write-arm64 --rc4 <on|off> <address> <file>
    openrockcli extra maskrom-exec-arm32 --rc4 <on|off> <address>
    openrockcli extra maskrom-exec-arm64 --rc4 <on|off> <address>
```

---

## 提示

1. `maskrom` 命令只能在 maskrom 模式下使用；执行其他命令前必须先执行 `maskrom` 命令。
2. 内存基地址从 **0** 开始，**不是** SDRAM 的物理地址。
3. 部分 u-boot rockusb 驱动中，Flash 转储操作被限制在起始 32MB 以内，可修补 u-boot 的宏 `RKUSB_READ_LIMIT_ADDR`：

```diff
diff --git a/u-boot/cmd/rockusb.c b/u-boot/cmd/rockusb.c
--- a/u-boot/cmd/rockusb.c
+++ b/u-boot/cmd/rockusb.c
@@ -26,7 +26,7 @@ static int rkusb_read_sector(struct ums *ums_dev,
        lbaint_t blkstart = start + ums_dev->start_sector;
        int ret;

-       if ((blkstart + blkcnt) > RKUSB_READ_LIMIT_ADDR) {
+       if ((blkstart + blkcnt) > RKUSB_READ_LIMIT_ADDR && 0) {
                memset(buf, 0xcc, blkcnt * SECTOR_SIZE);
                return blkcnt;
        } else {
```

---

## 芯片 Maskrom 示例

> ddr / usbplug 二进制文件可从 Rockchip 官方 loader 仓库获取（见文末"相关链接"）。

### RK3562（本 SDK 仓库重点平台）

```bash
openrockcli maskrom rk3562_ddr_1332MHz_v1.05.bin rk3562_usbplug_v1.04.bin --rc4-off
openrockcli version
```

等价 extra 命令：

```bash
openrockcli extra maskrom --rc4 off --sram rk3562_ddr_1332MHz_v1.05.bin --delay 10 --rc4 off --dram rk3562_usbplug_v1.04.bin --delay 10
openrockcli version
```

### RK3568（本 SDK 仓库重点平台）

```bash
openrockcli maskrom rk3568_ddr_1560MHz_v1.11.bin rk356x_usbplug_v1.13.bin --rc4-off
openrockcli version
```

等价 extra 命令：

```bash
openrockcli extra maskrom --rc4 off --sram rk3568_ddr_1560MHz_v1.11.bin --delay 10 --rc4 off --dram rk356x_usbplug_v1.13.bin --delay 10
openrockcli version
```

### RK3588

```bash
openrockcli maskrom rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin rk3588_usbplug_v1.11.bin --rc4-off
openrockcli version
```

- 初始化 ddr 内存：

```bash
openrockcli extra maskrom --rc4 off --sram rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin --delay 10
```

- 通过调试串口以 hex 格式转储内存区域：

```bash
openrockcli extra maskrom-dump-arm64 --rc4 off --uart 0xfeb50000 0xffff0000 1024
```

### RK3566

```bash
openrockcli maskrom rk3566_ddr_1056MHz_v1.11.bin rk356x_usbplug_v1.13.bin --rc4-off
openrockcli version
```

等价 extra 命令：

```bash
openrockcli extra maskrom --rc4 off --sram rk3566_ddr_1056MHz_v1.11.bin --delay 10 --rc4 off --dram rk356x_usbplug_v1.13.bin --delay 10
openrockcli version
```

### RK3399

```bash
openrockcli maskrom rk3399_ddr_800MHz_v1.30.bin rk3399_usbplug_v1.30.bin
openrockcli version
```

等价 extra 命令：

```bash
openrockcli extra maskrom --rc4 on --sram rk3399_ddr_800MHz_v1.30.bin --delay 10 --rc4 on --dram rk3399_usbplug_v1.30.bin --delay 10
openrockcli version
```

### RK3308

```bash
openrockcli maskrom rk3308_ddr_589MHz_uart2_m1_v1.31.bin rk3308_usbplug_v1.27.bin
openrockcli version
```

### RK3576

```bash
openrockcli maskrom rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.05.bin rk3576_usbplug_v1.02.bin --rc4-off
openrockcli version
```

### RK3506

```bash
openrockcli maskrom rk3506b_ddr_750MHz_v1.04.bin rk3506_usbplug_v1.02.bin --rc4-off
openrockcli version
```

### RV1106

```bash
openrockcli maskrom rv1106_ddr_924MHz_v1.15.bin rv1106_usbplug_v1.09.bin --rc4-off
openrockcli version
```

### RK1808

```bash
openrockcli maskrom rk1808_ddr_933MHz_v1.05.bin rk1808_usbplug_v1.05.bin
openrockcli version
```

### RK3128

```bash
openrockcli maskrom rk3128_ddr_300MHz_v2.12.bin rk3128_usbplug_v2.63.bin
openrockcli version
```

### RK3288

```bash
openrockcli maskrom rk3288_ddr_400MHz_v1.11.bin rk3288_usbplug_v2.63.bin
openrockcli version
```

### PX30

```bash
openrockcli maskrom px30_ddr_333MHz_v1.16.bin px30_usbplug_v1.31.bin
openrockcli version
```

### RK3399PRO

```bash
openrockcli maskrom rk3399pro_ddr_666MHz_v1.25.bin rk3399pro_usbplug_v1.26.bin
openrockcli version
```

---

## 常见烧录流程示例（RK3562 / RK3568）

```bash
# 1. 查看帮助
openrockcli --help

# 2. 让设备进入 Maskrom 模式（断电 → 按住 RECOVERY 键 → 插 USB → 松开），然后扫描
openrockcli scan

# 3. Maskrom 模式下初始化芯片（ddr + usbplug，注意芯片选择对应文件）
openrockcli maskrom rk3562_ddr_1332MHz_v1.05.bin rk3562_usbplug_v1.04.bin --rc4-off

# 4. 查看芯片版本确认初始化成功
openrockcli version

# 5. 查看固件包信息 / 解包
openrockcli inspect update.img
openrockcli unpack update.img ./extracted

# 6. 烧录完整固件
openrockcli flash update.img

# 7. 或仅烧录部分分区
openrockcli flash update.img --mode partition --partitions boot,uboot,trust

# 8. 烧录完成重启
openrockcli reset
```

---

## 注意事项

1. 设备需要进入 **Maskrom** 或 **Loader** 模式才能烧录；`maskrom` 命令必须在 maskrom 模式下执行。
2. 烧录过程中请勿断开 USB 连接，保持供电稳定。
3. 建议烧录前备份重要数据；`full_erase` 模式会擦除全部数据。
4. 固件需与芯片型号匹配，ddr / usbplug 文件选错会导致初始化失败。
5. 某些操作可能需要 root 权限（或配置 udev 规则）。
6. `--mode partition` 当前支持的分区有限（boot、uboot、misc、recovery、kernel、system、trust、resource、rootfs、oem、userdata），其他分区请使用底层 `upgrade_tool` 命令。

---

## 相关链接

- OpenRockCLI 项目：https://github.com/dshanpi/openrockcli
- Rockchip loader 二进制文件（ddr / usbplug）：https://github.com/rockchip-linux/rkbin
- Rockchip rkdeveloptool：https://github.com/rockchip-linux/rkdeveloptool
- 本仓库配套文档：[upgrade_tool_Tutorial.md](./upgrade_tool_Tutorial.md)

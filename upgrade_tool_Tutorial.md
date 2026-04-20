# Rockchip upgrade_tool 烧录工具

**upgrade_tool** 是瑞芯微（Rockchip）官方提供的 Linux 平台下 USB 烧录工具，支持统一固件（update.img）和分区镜像的烧写。

---

## 工具简介

| 项目 | 说明 |
|------|------|
| 工具名称 | upgrade_tool |
| 所属厂商 | Rockchip 官方 |
| 支持平台 | Linux |
| 支持存储 | eMMC、SPI Flash、SD Card、NAND |
| 固件格式 | 统一固件（update.img）、分区镜像 |

> **注意**：upgrade_tool 是闭源工具，仅提供二进制可执行文件。如需开源替代品，可使用 **rkdeveloptool**。

---

## 安装

### 系统依赖

```bash
# Ubuntu/Debian
sudo apt-get install libudev-dev libusb-1.0-0-dev

# Fedora
sudo dnf install libudev-devel libusb-devel

# Arch Linux
sudo pacman -S libusb
```

### 获取工具

#### 方法一：从 SDK 获取

在 Rockchip SDK 的以下路径可以找到：
```
tools/linux/Linux_Upgrade_Tool/upgrade_tool
```

#### 方法二：从 Radxa 官方下载（推荐）

```bash
# 下载最新版本（v2.30）
wget https://dl.radxa.com/rock/tools/linux/upgrade_tool_v2.30_for_linux.zip

# 或下载 v2.1 版本
wget https://dl.radxa.com/rock/tools/linux/Linux_Upgrade_Tool_V2.1.zip

# 解压
unzip upgrade_tool_v2.30_for_linux.zip

# 安装
chmod +x upgrade_tool
sudo mv upgrade_tool /usr/local/bin/
sudo chown root:root /usr/local/bin/upgrade_tool
```

---

## 设备模式

### 进入 Maskrom 模式

设备需要进入 **Maskrom** 或 **Loader** 模式才能烧录：

| 模式 | 说明 |
|------|------|
| Maskrom | 芯片内部 ROM 启动，等待 USB 烧录 |
| Loader | 引导加载器模式，可烧录固件 |

**进入方法**：
1. 断开设备电源
2. 按住 **RECOVERY** 键（或其他指定按键）
3. 连接 USB 线
4. 两秒后松开按键

---

## 命令详解

### 常用命令

| 命令 | 简写 | 说明 |
|------|------|------|
| `H` | 帮助 | 显示帮助信息 |
| `V` | 版本 | 显示工具版本 |
| `LD` | 列出设备 | 列出已连接的 Rockchip 设备 |
| `CD` | 选择设备 | 选择要操作的设备 |
| `UF` | 升级固件 | 烧写统一固件 update.img |
| `UL` | 升级Loader | 烧写 Loader |
| `DB` | 下载引导 | 下载引导镜像 |
| `DI` | 下载镜像 | 烧写分区镜像 |
| `EF` | 擦除Flash | 擦除 Flash |
| `RD` | 重启设备 | 重启目标设备 |
| `RID` | 读取Flash ID | 读取 Flash 芯片 ID |
| `RFI` | 读取Flash信息 | 读取 Flash 详细信息 |
| `RCI` | 读取芯片信息 | 读取芯片信息 |

### 分区镜像参数

| 参数 | 说明 |
|------|------|
| `-p` | parameter 分区 |
| `-b` | boot 分区 |
| `-k` | kernel 分区 |
| `-s` | security 分区 |
| `-r` | recovery 分区 |
| `-m` | misc 分区 |
| `-u` | uboot 分区 |
| `-t` | trust 分区 |
| `-re` | resource 分区 |
| `-rootfs` | rootfs 分区 |

---

## 烧录示例

### 1. 烧录统一固件（推荐）

最简单的方式，烧写完整的 update.img：

```bash
sudo upgrade_tool uf update.img
```

### 2. 烧录分区镜像

#### 步骤1：烧写 Loader

```bash
sudo upgrade_tool ul MiniLoaderAll.bin
```

或：

```bash
sudo upgrade_tool db rk3568_loader.bin
```

#### 步骤2：烧写分区镜像

```bash
# 烧写 parameter
sudo upgrade_tool di -p parameter.txt

# 烧写 uboot
sudo upgrade_tool di -u uboot.img

# 烧写 trust
sudo upgrade_tool di -t trust.img

# 烧写 boot
sudo upgrade_tool di -b boot.img

# 烧写 rootfs
sudo upgrade_tool di -rootfs rootfs.img
```

#### 步骤3：重启设备

```bash
sudo upgrade_tool rd
```

### 3. 完整烧录流程示例（RK3568）

```bash
# 1. 查看已连接设备
sudo upgrade_tool ld

# 2. 烧写 Loader
sudo upgrade_tool db rk3568_loader.bin

# 3. 烧写各分区镜像
sudo upgrade_tool di -p parameter.txt
sudo upgrade_tool di -u uboot.img
sudo upgrade_tool di -t trust.img
sudo upgrade_tool di -b boot.img
sudo upgrade_tool di -rootfs rootfs.img

# 4. 重启设备
sudo upgrade_tool rd
```

### 4. 擦除 Flash

```bash
# 擦除 Flash（低格）
sudo upgrade_tool lf

# 擦除 Flash（快速擦除）
sudo upgrade_tool ef
```

---

## 常见问题

### 1. 设备未检测到

**现象**：`List of rockusb connected(0)`

**解决方法**：
- 检查 USB 线是否正常
- 确认设备已进入 Maskrom/Loader 模式
- 尝试更换 USB 端口
- 检查是否有其他程序占用设备

### 2. 烧录失败

**现象**：烧录过程中报错

**解决方法**：
- 尝试先擦除 Flash：`sudo upgrade_tool ef`
- 检查固件是否与芯片型号匹配
- 确保供电稳定

### 3. 权限问题

**现象**：`Permission denied`

**解决方法**：
- 使用 sudo 运行
- 或配置 udev 规则：

```bash
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0666"' | sudo tee /etc/udev/rules.d/50-rockchip.rules
sudo udevadm control --reload-rules
```

---

## rkdeveloptool 替代方案

如果不想使用闭源的 upgrade_tool，可以使用开源的 **rkdeveloptool**：

### 安装

```bash
# 安装依赖
sudo apt-get install libudev-dev libusb-1.0-0-dev dh-autoreconf pkg-config

# 克隆源码
git clone https://github.com/rockchip-linux/rkdeveloptool
cd rkdeveloptool

# 编译
autoreconf -i
./configure
make -j $(nproc)
sudo make install
```

### 常用命令

| 命令 | 说明 |
|------|------|
| `rkdeveloptool ld` | 列出设备 |
| `rkdeveloptool db <loader>` | 下载引导 |
| `rkdeveloptool wl <addr> <file>` | 写入镜像 |
| `rkdeveloptool rd` | 重启设备 |

### 烧录示例

```bash
# 烧写 Loader
sudo rkdeveloptool db rk3568_loader.bin

# 烧写固件
sudo rkdeveloptool wl 0x40 idbloader.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool wl 0x8000 boot.img
sudo rkdeveloptool wl 0x40000 rootfs.img

# 重启
sudo rkdeveloptool rd
```

---

## 速查表

```bash
# 查看已连接设备
sudo upgrade_tool ld

# 烧录统一固件（最简单）
sudo upgrade_tool uf update.img

# 烧录分区镜像
sudo upgrade_tool db <loader>
sudo upgrade_tool di -p parameter.txt
sudo upgrade_tool di -u uboot.img
sudo upgrade_tool di -t trust.img
sudo upgrade_tool di -b boot.img
sudo upgrade_tool di -rootfs rootfs.img
sudo upgrade_tool rd

# 擦除 Flash
sudo upgrade_tool ef

# 重启设备
sudo upgrade_tool rd
```

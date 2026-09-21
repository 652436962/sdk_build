# 华云 RK3562 SDK Docker 编译环境使用文档
**适用系统**：Ubuntu 20.04.6
**适用平台**：瑞芯微 RK3562 系列开发板（华云项目）
**SDK 来源**：从 `rk3562_sdk` 复制分支，独立维护
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言
本文专为华云 RK3562 SDK 编译打造，基于 Docker 搭建 Ubuntu 20.04 标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。

核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

> **环境状态**：容器 `huayun-sdk` 已创建，编译依赖已安装，编译脚本修复已应用，可直接编译。

---

## 一、前期准备
### 1.1 前提条件
1. 本机系统：Ubuntu 20.04.6（推荐纯净系统，无冗余软件源冲突）
2. 华云 RK3562 SDK 位于 `/media/lechi/linuxsdk/linuxsdk/huayun_sdk`，**存放路径无中文、空格、特殊字符**
3. 网络正常，可拉取 Docker 镜像、下载系统依赖包

### 1.2 安装 Docker（仅执行一次）
打开终端，逐行执行以下命令，安装并配置 Docker 环境：
```bash
# 刷新软件源
sudo apt update
# 安装 Docker
sudo apt install docker.io -y
# 设置 Docker 开机自启
sudo systemctl enable docker
# 启动 Docker 服务
sudo systemctl start docker
# 将当前用户加入 docker 组，后续使用免 sudo
sudo usermod -aG docker $USER
```
**关键操作**：执行完成后，**必须注销当前用户并重新登录**，否则 Docker 权限配置不生效。

### 1.3 SDK 目录权限修复（仅执行一次）
进入华云 SDK 根目录，修复文件权限，避免编译时报读写权限错误：
```bash
cd /media/lechi/linuxsdk/linuxsdk/huayun_sdk
sudo chown -R $USER:$USER .
```

---

## 二、进入 Docker 编译环境
### 2.1 容器信息
容器已预先创建并配置完毕：

| 项目 | 值 |
|------|-----|
| 容器名 | `huayun-sdk` |
| 镜像 | `ubuntu:20.04` |
| 主机名 | `huayun-build` |
| 挂载 | `huayun_sdk` → `/workspace` |
| GCC | 9.4.0 |
| Python | `python` → `python3` (3.8.10) |
| 时区 | Asia/Shanghai (CST) |

### 2.2 重新进入已存在的容器
```bash
docker start huayun-sdk
docker exec -it huayun-sdk /bin/bash
```

环境就绪标识：终端提示符变为
`root@huayun-build:/workspace#`

### 2.3 首次创建容器（参考，已执行）
如需重建容器，使用以下命令：
```bash
cd /media/lechi/linuxsdk/linuxsdk/huayun_sdk
docker run -dit \
  --name huayun-sdk \
  -e DEBIAN_FRONTEND=noninteractive \
  -e TZ=Asia/Shanghai \
  -v $(pwd):/workspace \
  -w /workspace \
  -h huayun-build \
  ubuntu:20.04 \
  /bin/bash
```

---

## 三、安装编译依赖（已预装）
容器内编译依赖已全部预装，**无需重复执行**。依赖列表如下（供参考）：

```bash
apt update && apt-get install -y \
git ssh make gcc libssl-dev \
liblz4-tool expect expect-dev g++ patchelf chrpath gawk texinfo chrpath \
diffstat binfmt-support qemu-user-static live-build bison flex fakeroot \
cmake gcc-multilib g++-multilib unzip device-tree-compiler ncurses-dev \
libgucharmap-2-90-dev bzip2 expat gpgv2 cpp-aarch64-linux-gnu libgmp-dev \
libmpc-dev bc python-is-python3 python2 libpkgconf-dev rsync bsdmainutils
```

> **说明**：`rsync` 和 `bsdmainutils`（包含 hexdump）是打包固件镜像时的必需依赖。

---

## 四、SDK 编译指令
在 Docker 容器内，直接执行编译命令，根据需求选择：

### 4.1 全量编译（推荐，生成完整刷机固件）
```bash
./ubuntu/build.sh all
```

### 4.2 其他常用编译命令
```bash
# 仅编译 U-Boot
./ubuntu/build.sh uboot 

# 编译完成后将生成 uboot.img idblock.img rk3562_spl_loader_v1.05.106.bin
# 备注：编译 U-Boot 后生成的 U-Boot SPL 镜像为 rk3562_spl_loader_v1.05.106.bin，需重命名为 MiniLoaderAll.bin 后再替换 Image 目录下原有同名文件

# 仅编译内核
./ubuntu/build.sh kernel
# 编译完成后，将生成内核镜像文件 boot.img。

# 配置内核选项
./ubuntu/build.sh menuconfig
```

编译时长：10~30 分钟（取决于 CPU 核心数与内存）
**固件输出路径**：`ubuntu/rockchip/output/update/Image/` 文件夹

---

## 五、退出与重新进入
### 5.1 退出容器
容器内执行 `exit`，本机 SDK 文件不受影响：
```bash
exit
```

### 5.2 下次编译流程
```bash
docker start huayun-sdk
docker exec -it huayun-sdk /bin/bash
```
进入后直接执行编译命令，**无需重复安装依赖**。

---

## 六、编译脚本修复（已预应用）
以下修复已在容器创建时一次性应用完毕，**无需重复操作**。仅当 SDK 中 `build.sh` 被替换后才需要重新执行。

### 6.1 修复清单

| 序号 | 问题 | 修复命令 |
|------|------|----------|
| 1 | U-Boot 目录大小写 | `sed -i 's\|/workspace/ubuntu/u-boot\|/workspace/ubuntu/U-boot\|g' /workspace/ubuntu/build.sh` |
| 2 | U-Boot defconfig | `sed -i 's/tl3562-evm_defconfig/rk3562_defconfig/g' /workspace/ubuntu/build.sh` |
| 3 | gcc-wrapper 禁用 | `mv /workspace/ubuntu/Kernel/scripts/gcc-wrapper.py /workspace/ubuntu/Kernel/scripts/gcc-wrapper.py.bak` |
| 4 | python 软链接 | `ln -sf /usr/bin/python3 /usr/bin/python` |
| 5 | build.sh 执行权限 | `chmod +x /workspace/ubuntu/build.sh` |

### 6.2 常见编译问题（备用参考）

#### 问题1：U-Boot 目录大小写错误
**现象**：`cd: /workspace/ubuntu/u-boot: No such file or directory`
**原因**：SDK 目录为大写 `U-boot`，脚本使用小写。
**修复**：`sed -i 's|/workspace/ubuntu/u-boot|/workspace/ubuntu/U-boot|g' /workspace/ubuntu/build.sh`

#### 问题2：U-Boot 配置文件不存在
**现象**：`Can't find default configuration "tl3562-evm_defconfig"`
**原因**：配置文件为 `rk3562_defconfig`，脚本使用错误的名称。
**修复**：`sed -i 's/tl3562-evm_defconfig/rk3562_defconfig/g' /workspace/ubuntu/build.sh`

#### 问题3：gcc-wrapper.py 编译失败
**现象**：`gcc-wrapper.py: unknown assembler invoked`
**原因**：gcc-wrapper 与交叉编译工具链不兼容。
**修复**：`mv /workspace/ubuntu/Kernel/scripts/gcc-wrapper.py /workspace/ubuntu/Kernel/scripts/gcc-wrapper.py.bak`

#### 问题4：缺少 python 命令
**现象**：`'python': No such file or directory`
**原因**：系统只有 `python3`。
**修复**：`ln -sf /usr/bin/python3 /usr/bin/python`

---

## 七、容器时区设置（已预配置）
容器时区已设为 Asia/Shanghai (CST)，如需修改，在容器内执行：
```bash
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone
```

---

## 八、注意事项
1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. 禁止执行 `sudo apt upgrade` 等系统升级命令，避免破坏编译环境
3. 如需彻底删除容器重建环境，执行 `docker stop huayun-sdk && docker rm huayun-sdk`
4. 出现 `Permission denied` 权限报错，回到本机执行 1.3 节权限修复命令
5. Docker 安装后必须注销重登，否则无法正常使用容器
6. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
7. 华云 SDK 与 rk3562_sdk 为独立分支，各自维护，互不影响

---

## 九、板端看门狗测试

TL3562-EVM 支持两种看门狗操作方式：**软件驱动喂狗**（通过 `/dev/watchdog`）和**硬件 GPIO 喂狗**（通过 GPIO 495 翻转电平）。

### 9.1 软件驱动喂狗（fltest_watchdog）
```bash
./fltest_watchdog
# 预期输出：Watchdog Ticking Away!

# 关闭看门狗
./fltest_watchdog -d

# 使能看门狗
./fltest_watchdog -e
```
> 源码路径：`forlinx_cmd/fltest_watchdog/watchdog.c`

### 9.2 看门狗重启测试（fltest_watchdogrestart）
```bash
./fltest_watchdogrestart
# 预期：10 秒后系统复位重启
```
> 源码路径：`forlinx_cmd/fltest_watchdogrestart/watchdogrestart.c`

### 9.3 硬件 GPIO 喂狗
```bash
echo 495 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio495/direction

while true; do
    echo 1 > /sys/class/gpio/gpio495/value
    sleep 1
    echo 0 > /sys/class/gpio/gpio495/value
    sleep 1
done
```
> 硬件 GPIO 喂狗不依赖内核看门狗驱动，直接操作 GPIO 向看门狗芯片发送脉冲信号。若停止翻转电平，看门狗芯片在超时后将触发系统复位。

---

## 十、固件烧写与板端验证

### 10.1 烧写工具
```bash
which upgrade_tool          # /usr/local/bin/upgrade_tool
```

### 10.2 设备进入烧写模式

| 模式 | 说明 | 进入方法 |
|------|------|----------|
| Maskrom | 芯片内部 ROM 启动 | 断电 → 按住 RECOVERY → 上电 → 2 秒后松键 |
| Loader | 引导加载器模式 | 系统内执行 `reboot loader` |

### 10.3 烧写统一固件
```bash
# 1. 检查设备连接
sudo upgrade_tool LD
# 预期输出：List of rockusb connected(1) ... Mode=Maskrom

# 2. 烧写 update.img（全量烧写）
sudo upgrade_tool uf /media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/rockchip/output/update/Image/update.img
```
> 烧写完成后设备会自动重启进入新系统。

### 10.4 分步烧写（仅更新特定分区）
```bash
cd /media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/rockchip/output/update/Image/

sudo upgrade_tool ul MiniLoaderAll.bin
sudo upgrade_tool di -p parameter.txt
sudo upgrade_tool di -u uboot.img
sudo upgrade_tool di -b boot.img
sudo upgrade_tool di -rootfs rootfs.img
sudo upgrade_tool rd
```

### 10.5 板端 SSH 验证
```bash
# 板端 IP：192.168.10.22
ssh root@192.168.10.22
```

---

## 快捷操作总结（一键记忆）

### 首次使用（容器已创建，跳过创建步骤）
```bash
# 1. 启动容器
docker start huayun-sdk
# 2. 进入容器，编译
docker exec -it huayun-sdk bash -c "cd /workspace && ./ubuntu/build.sh all"
```

### 后续使用（直接进入已存在容器）
```bash
docker start huayun-sdk
docker exec -it huayun-sdk /bin/bash
```

### overlay 变更快速打包（跳过 U-Boot/内核）
```bash
docker exec huayun-sdk bash -c "cd /workspace/ubuntu && cp rootfs/rootfs.img rockchip/output/Image/ && cd rockchip && ./mkimage.sh pack"
```

### 烧写固件到板端
```bash
# 1. 设备断电 → 按住 RECOVERY → 上电 → 2 秒后松键（进入 Maskrom）
# 2. 烧写
sudo upgrade_tool uf /media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/rockchip/output/update/Image/update.img
```

> **固件输出位置**：`/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/rockchip/output/update/Image/update.img`

---

## 附录

### 设备树说明

内核默认编译的设备树为 **tl3562-evm**，支持 TL3562-EVM 开发板的基本外设（网口、USB、UART、GPIO、eMMC、SD卡、音频等）。

**设备树源文件路径**：

| 文件类型 | 路径 |
|---------|------|
| 设备树（DTS） | [`ubuntu/Kernel/arch/arm64/boot/dts/rockchip/tl3562-evm.dts`](/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/Kernel/arch/arm64/boot/dts/rockchip/tl3562-evm.dts) |
| 内核 defconfig | [`ubuntu/Kernel/arch/arm64/configs/rockchip_linux_defconfig`](/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/Kernel/arch/arm64/configs/rockchip_linux_defconfig) |

该设备树引用以下 dtsi 公共配置文件（完整路径均为 `ubuntu/Kernel/arch/arm64/boot/dts/rockchip/`）：

| 文件 | 路径 | 说明 |
|------|------|------|
| `rk3562-evb2-ddr4-v10.dtsi` | [`ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-evb2-ddr4-v10.dtsi`](/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-evb2-ddr4-v10.dtsi) | DDR4 内存配置 |
| `rk3562-linux.dtsi` | [`ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-linux.dtsi`](/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-linux.dtsi) | Linux 通用外设配置 |
| `rk3562-rk809.dtsi` | [`ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-rk809.dtsi`](/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-rk809.dtsi) | RK809 电源管理芯片配置 |
| `rk3562-amp.dtsi` | [`ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-amp.dtsi`](/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-amp.dtsi) | AMP（非对称多处理）配置 |
| `rk3562-evb.dtsi` | [`ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-evb.dtsi`](/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562-evb.dtsi) | EVB 板级公共配置（由 rk3562-evb2-ddr4-v10.dtsi 引入） |
| `rk3562.dtsi` | [`ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562.dtsi`](/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/Kernel/arch/arm64/boot/dts/rockchip/rk3562.dtsi) | RK3562 SoC 核心定义（外设基地址、中断、时钟等，由 rk3562-evb2-ddr4-v10.dtsi 引入） |

**SDK 中存在的设备树文件**：

| 文件 | 说明 |
|------|------|
| `tl3562-evm.dts` | 默认编译的设备树，支持TL3562-EVM基本外设（网口、USB、UART、GPIO、eMMC、SD卡、音频等），不支持MIPI LCD、LVDS LCD、SDIO WIFI以及蓝牙音频设备。 |
| `tl3562-evm-bluetooth-audio.dts` | 基于默认设备树，支持蓝牙音频设备，不支持MIC、喇叭、有线耳机。 |
| `tl3562-evm-lvds-lcd.dts` | 基于默认设备树，支持LVDS LCD显示，不支持HDMI OUT显示。 |
| `tl3562-evm-mipi-lcd.dts` | 基于默认设备树，支持MIPI LCD显示，不支持HDMI OUT显示。 |
| `tl3562-evm-sdio-wifi.dts` | 基于默认设备树，支持SDIO WIFI，不支持5G。 |

> 编译内核时，`build.sh` 会自动使用 `tl3562-evm.dts` 作为默认设备树，编译生成 `tl3562-evm.img` 内核镜像。

### 交叉编译工具链（备选）

编译脚本已自动设置工具链，如需手动设置，可执行以下命令：

#### 1. U-Boot 和内核编译工具链
```bash
export PATH=/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
```

#### 2. 应用编译工具链
```bash
source /media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/environment
make CC=aarch64-linux-gnu-gcc
```

---

**备注**：本文档适配华云 RK3562 Ubuntu SDK，由 `rk3562_sdk` 分支而来，Docker 环境与官方编译要求完全一致。

# RK3562 SDK Docker 编译环境完整使用文档
**适用系统**：Ubuntu 20.04.6
**适用平台**：瑞芯微 RK3562 系列开发板（创龙）
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言
本文专为瑞芯微 RK3562 SDK 编译打造，基于 Docker 搭建 Ubuntu 20.04 标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

---

## 一、前期准备
### 1.1 前提条件
1. 本机系统：Ubuntu 20.04.6（推荐纯净系统，无冗余软件源冲突）
2. RK3562 完整 SDK 已解压完成，**存放路径无中文、空格、特殊字符**
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
进入 RK3562 SDK 根目录，修复文件权限，避免编译时报读写权限错误：
```bash
# 进入 SDK 根目录（替换为你实际的 SDK 路径）
cd /media/lechi/linuxsdk/linuxsdk/rk3562_sdk
# 修复目录归属（推荐）
sudo chown -R $USER:$USER .
# 备用命令（上一条命令报错时使用）
# sudo chmod -R 777 .
```

---

## 二、进入 Docker 编译环境
### 2.1 启动容器命令（首次执行）
**先进入本机 RK3562 SDK 根目录**，再执行以下命令，自动进入编译容器：
```bash
docker run -it \
--name rk3562-sdk \
-v $(pwd):/workspace \
-w /workspace \
-h rk3562-build \
ubuntu:20.04 \
/bin/bash
```

> **注意**：此处已移除 `--rm` 参数，用于保留容器环境，避免每次重复安装依赖。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name rk3562-sdk` | 容器命名，区分开发板型号 |
| `-v $(pwd):/workspace` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /workspace` | 容器内默认进入 SDK 工作目录 |
| `-h rk3562-build` | 设置容器主机名，方便识别 |

### 2.3 重新进入已存在的容器
查看容器命令
sudo docker ps -a

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
docker start rk3562-sdk
docker exec -it rk3562-sdk /bin/bash
```

环境就绪标识：终端提示符变为
`root@rk3562-build:/workspace#`

---

## 三、安装编译依赖（仅首次进入容器安装）
在 Docker 容器内执行以下命令，一键安装 RK3562 SDK 全部编译依赖：
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

依赖安装完成后，给编译脚本添加执行权限：
```bash
chmod +x ubuntu/build.sh
```

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
#备注：编译 U-Boot 后生成的 U-Boot SPL 镜像为 rk3562_spl_loader_v1.05.106.bin，需重命名为 MiniLoaderAll.bin 后再替换 Image 目录下原有同名文件

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
1. 进入本机 SDK 根目录
2. 执行以下命令重新进入已存在的容器：
   ```bash
   docker start rk3562-sdk
   docker exec -it rk3562-sdk /bin/bash
   ```
3. 直接执行编译命令，**无需重复安装依赖**

---

## 六、常见问题与修复

### 6.1 U-Boot 编译问题

#### 问题1：U-Boot 目录大小写错误
**现象**：执行 `./ubuntu/build.sh uboot` 时报错：
```
./ubuntu/build.sh: line 65: cd: /workspace/ubuntu/u-boot: No such file or directory
```

**原因**：`build.sh` 脚本中使用的是小写的 `u-boot`，但实际 SDK 中的目录是大写的 `U-boot`。

**修复方法**：在容器内执行以下命令修复：
```bash
sed -i 's|/workspace/ubuntu/u-boot|/workspace/ubuntu/U-boot|g' /workspace/ubuntu/build.sh
```

#### 问题2：U-Boot 配置文件不存在
**现象**：执行 `./ubuntu/build.sh uboot` 时报错：
```
*** Can't find default configuration "arch/../configs/tl3562-evm_defconfig"!
```

**原因**：`build.sh` 脚本中使用的配置是 `tl3562-evm_defconfig`，但实际 SDK 中存在的配置文件是 `rk3562_defconfig`。

**修复方法**：在容器内执行以下命令修复：
```bash
sed -i 's/tl3562-evm_defconfig/rk3562_defconfig/g' /workspace/ubuntu/build.sh
```

**注意**：以上修复只需执行一次，修复后的脚本会持久化保存到 SDK 中。

### 6.2 内核编译问题

#### 问题3：gcc-wrapper.py 导致编译失败
**现象**：执行 `./ubuntu/build.sh kernel` 时报错：
```
/workspace/ubuntu/Kernel/scripts/gcc-wrapper.py aarch64-none-linux-gnu-gcc: unknown assembler invoked
scripts/Kconfig.include:47: Sorry, this assembler is not supported.
```

**原因**：内核源码中的 `gcc-wrapper.py` 脚本与交叉编译工具链不兼容。

**修复方法**：在容器内执行以下命令禁用 gcc-wrapper：
```bash
mv /workspace/ubuntu/Kernel/scripts/gcc-wrapper.py /workspace/ubuntu/Kernel/scripts/gcc-wrapper.py.bak
```

#### 问题4：缺少 python 命令
**现象**：编译过程中报错：
```
/usr/bin/env: 'python': No such file or directory
make: *** [arch/arm64/Makefile:215: tl3562-evm.img] Error 127
```

**原因**：系统中只有 `python3`，没有 `python` 命令。

**修复方法**：创建软链接：
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

---

## 七、容器时区设置（可选）

如需将容器时区设置为北京时间（Asia/Shanghai），在容器内执行：
```bash
# 安装时区数据（如未安装）
apt-get install -y tzdata

# 设置时区为上海
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 验证
date
```

---

## 八、注意事项
1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. 禁止执行 `sudo apt upgrade` 等系统升级命令，避免破坏编译环境
3. 如需彻底删除容器重建环境，执行 `docker stop rk3562-sdk && docker rm rk3562-sdk`
4. 出现 `Permission denied` 权限报错，回到本机执行 1.3 节权限修复命令
5. Docker 安装后必须注销重登，否则无法正常使用容器
6. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏

---

## 九、板端看门狗测试

TL3562-EVM 支持两种看门狗操作方式：**软件驱动喂狗**（通过 `/dev/watchdog`）和**硬件 GPIO 喂狗**（通过 GPIO 495 翻转电平）。

### 9.1 软件驱动喂狗（fltest_watchdog）

通过 `/dev/watchdog` 驱动周期性发送 `WDIOC_KEEPALIVE` 指令喂狗，超时时间 10 秒：

```bash
# 运行看门狗喂狗测试
./fltest_watchdog

# 预期输出
# Watchdog Ticking Away!
```

```bash
# 关闭看门狗
./fltest_watchdog -d

# 使能看门狗
./fltest_watchdog -e
```

> 源码路径：`forlinx_cmd/fltest_watchdog/watchdog.c`

### 9.2 看门狗重启测试（fltest_watchdogrestart）

打开看门狗后故意不喂狗，10 秒后系统自动重启：

```bash
./fltest_watchdogrestart
# 预期：10 秒后系统复位重启
```

> 源码路径：`forlinx_cmd/fltest_watchdogrestart/watchdogrestart.c`

### 9.3 硬件 GPIO 喂狗

通过 GPIO 495 翻转电平直接给看门狗芯片的 WDI 引脚发送喂狗信号，属于硬件层面的喂狗方式：

```bash
# 导出 GPIO 495
echo 495 > /sys/class/gpio/export

# 设置 GPIO 495 为输出模式
echo out > /sys/class/gpio/gpio495/direction

# 循环翻转 GPIO 电平喂狗（1 秒高电平，1 秒低电平）
while true; do
    echo 1 > /sys/class/gpio/gpio495/value
    sleep 1
    echo 0 > /sys/class/gpio/gpio495/value
    sleep 1
done
```

> **说明**：硬件 GPIO 喂狗不依赖内核看门狗驱动，直接操作 GPIO 向看门狗芯片发送脉冲信号。若停止翻转电平，看门狗芯片在超时后将触发系统复位。


---

## 十、固件烧写与板端验证

### 10.1 烧写工具

使用 Rockchip 官方 `upgrade_tool` 通过 USB 烧写固件：

```bash
# 工具路径（系统已安装）
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
sudo upgrade_tool uf /media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rockchip/output/update/Image/update.img

# 预期输出：
# Download Firmware Start
# Download Image... (100%)
# Download Firmware Success
# Upgrade firmware ok.
```

> 烧写完成后设备会自动重启进入新系统。

### 10.4 分步烧写（仅更新特定分区）

若只需更新部分分区镜像（如仅 rootfs 变更），避免全量烧写：

```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rockchip/output/update/Image/

# 先下载 Loader
sudo upgrade_tool ul MiniLoaderAll.bin

# 烧写各分区
sudo upgrade_tool di -p parameter.txt
sudo upgrade_tool di -u uboot.img
sudo upgrade_tool di -b boot.img
sudo upgrade_tool di -rootfs rootfs.img

# 重启
sudo upgrade_tool rd
```

### 10.5 板端 SSH 验证

设备启动后通过 SSH 登录验证 overlay 配置是否生效：

```bash
# 板端 IP：192.168.10.22
ssh root@192.168.10.22
```

**验证项**：

```bash
# 1. 主机名
cat /etc/hostname
# 预期：Lechi

# 2. rebootcheck 服务（开机执行一次记录启动计数）
systemctl status rebootcheck.service
# 预期：inactive (dead)，Succeeded
cat /opt/boot_count.log
# 预期：Boot #N at YYYY-MM-DD HH:MM:SS

# 3. watchdog 服务（GPIO 喂狗常驻运行）
systemctl status watchdog.service
# 预期：active (running)

# 4. 检查 overlay 部署文件
ls -la /opt/rebootcheck/ /opt/watchdog/
ls /etc/systemd/system/rebootcheck.service /etc/systemd/system/watchdog.service
```

### 10.6 远程重启验证

验证 rebootcheck 服务在重启后计数递增：

```bash
# SSH 登录后重启
ssh root@192.168.10.22 reboot

# 等待设备重启（约 30 秒），重新登录
ssh root@192.168.10.22

# 查看计数是否 +1
cat /opt/boot_count.log
```

## 快捷操作总结（一键记忆）

### 首次使用（创建容器并安装依赖）
```bash
# 1. 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3562_sdk
# 2. 启动 Docker 容器（首次创建）
docker run -it --name rk3562-sdk -v $(pwd):/workspace -w /workspace -h rk3562-build ubuntu:20.04 /bin/bash

# 失败，换源
sudo tee /etc/docker/daemon.json <<EOF
{
"registry-mirrors": ["https://ccr.ccs.tencentyun.com/"]
}
EOF

sudo systemctl daemon-reload && sudo systemctl restart docker

# 3. 在容器内安装依赖
apt update && apt-get install -y git ssh make gcc libssl-dev liblz4-tool expect expect-dev g++ patchelf chrpath gawk texinfo diffstat binfmt-support qemu-user-static live-build bison flex fakeroot cmake gcc-multilib g++-multilib unzip device-tree-compiler ncurses-dev libgucharmap-2-90-dev bzip2 expat gpgv2 cpp-aarch64-linux-gnu libgmp-dev libmpc-dev bc python-is-python3 python2 libpkgconf-dev rsync bsdmainutils
# 4. 添加执行权限
chmod +x ubuntu/build.sh
# 5. 开始编译
./build.sh all
# 6. 退出
exit
```

### 后续使用（直接进入已存在容器）
```bash
# 1. 启动已存在的容器
docker start rk3562-sdk
# 2. 进入容器，执行编译
docker exec -it rk3562-sdk bash -c "cd /workspace/ubuntu && ./build.sh all"
```

### overlay 变更快速打包（跳过 U-Boot/内核）
```bash
# 仅 overlay 内容变更时，无需完整重编
docker exec -it rk3562-sdk bash -c "cd /workspace/ubuntu && cp rootfs/rootfs.img rockchip/output/Image/ && cd rockchip && ./mkimage.sh pack"
```

### 烧写固件到板端
```bash
# 1. 设备断电 → 按住 RECOVERY → 上电 → 2 秒后松键（进入 Maskrom）
# 2. 烧写
sudo upgrade_tool uf /media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rockchip/output/update/Image/update.img
# 3. 设备自动重启，SSH 验证
ssh root@192.168.10.22
cat /etc/hostname                    # 预期：Lechi
systemctl status watchdog.service    # 预期：active (running)
cat /opt/boot_count.log              # 预期：Boot #N ...
```

> **固件输出位置**：`/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rockchip/output/update/Image/update.img`
> 
> 详细步骤参考：`rootfs_mount_guide.md`（文件系统修改）、`upgrade_tool_Tutorial.md`（烧录工具）。

---
**备注**：本文档适配官方 RK3562 Ubuntu SDK，Docker 环境与官方编译要求完全一致。









## 附录

### 设备树说明

内核默认编译的设备树为 **tl3562-evm**，支持 TL3562-EVM 开发板的基本外设（网口、USB、UART、GPIO、eMMC、SD卡、音频等）。

**设备树源文件路径**：

| 文件类型 | 路径 |
|---------|------|
| 设备树（DTS） | [`ubuntu/Kernel/arch/arm64/boot/dts/rockchip/tl3562-evm.dts`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/Kernel/arch/arm64/boot/dts/rockchip/tl3562-evm.dts) |
| 内核 defconfig | [`ubuntu/Kernel/arch/arm64/configs/rockchip_linux_defconfig`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/Kernel/arch/arm64/configs/rockchip_linux_defconfig) |

该设备树引用以下 dtsi 公共配置文件：

| 文件 | 说明 |
|------|------|
| `rk3562-evb2-ddr4-v10.dtsi` | DDR4 内存配置 |
| `rk3562-linux.dtsi` | Linux 通用外设配置 |
| `rk3562-rk809.dtsi` | RK809 电源管理芯片配置 |
| `rk3562-amp.dtsi` | AMP（非对称多处理）配置 |

**SDK 中存在的设备树文件**：

| 文件 | 说明 |
|------|------|
| `tl3562-evm.dts` | 默认编译的设备树，支持TL3562-EVM基本外设（网口、USB、UART、GPIO、eMMC、SD卡、音频等），不支持MIPI LCD、LVDS LCD、SDIO WIFI以及蓝牙音频设备（通过WIFI/BT接口接入TL8800I模块实现）。 |
| `tl3562-evm-bluetooth-audio.dts` | 基于默认设备树，支持蓝牙音频设备（通过WIFI/BT接口接入TL8800I模块实现），不支持MIC、喇叭、有线耳机。 |
| `tl3562-evm-lvds-lcd.dts` | 基于默认设备树，支持LVDS LCD显示，不支持HDMI OUT显示。 |
| `tl3562-evm-mipi-lcd.dts` | 基于默认设备树，支持MIPI LCD显示，不支持HDMI OUT显示。 |
| `tl3562-evm-sdio-wifi.dts` | 基于默认设备树，支持SDIO WIFI，不支持5G。 |

> 编译内核时，`build.sh` 会自动使用 `tl3562-evm.dts` 作为默认设备树，编译生成 `tl3562-evm.img` 内核镜像。

### Overlay 自定义集成（rootfs 定制）

SDK 支持通过 **overlay 机制** 将自定义配置（主机名、systemd 服务、脚本程序等）自动集成到 rootfs 中，编译烧写后即可开箱即用，无需手动 scp 部署。

#### 原理

`mkimage.sh pack` 打包阶段会自动调用 `post-overlay.sh`，将 `overlays/rootfs/` 下的文件通过 rsync 覆盖到 rootfs：

```
overlays/rootfs/lechi/            mkimage.sh pack
    ├── etc/hostname          ──→  ┌─────────────────┐
    ├── etc/hosts             ──→  │  post-overlay.sh │  ──→  rootfs.img（含所有自定义配置）
    ├── opt/watchdog/         ──→  │  (rsync +        │
    ├── opt/rebootcheck/      ──→  │   systemd link)  │
    ├── etc/systemd/system/   ──→  └─────────────────┘
    └── install.sh
```

#### Overlay 目录结构

```
ubuntu/rockchip/device/rockchip/common/overlays/rootfs/lechi/
├── install.sh                                    # 安装脚本（SDK 自动调用）
├── etc/
│   ├── hostname                                  # 主机名 → Lechi
│   ├── hosts                                     # hosts 映射（127.0.1.1 Lechi）
│   └── systemd/system/
│       ├── watchdog.service                      # GPIO 看门狗喂狗服务（Type=simple）
│       └── rebootcheck.service                   # 重启检测服务（Type=oneshot）
└── opt/
    ├── watchdog/
    │   └── watchdog.sh                           # GPIO 495 翻转喂狗脚本
    └── rebootcheck/
        └── fltest_rebootcheck                    # 启动计数二进制程序
└── gpio/
    └── lctest_gpio.sh                       # GPIO 控制脚本（全志/瑞芯微）
```

#### install.sh 核心逻辑

```bash
#!/bin/bash -e
TARGET_DIR="$1"
POST_OS="$2"

# 1. rsync 所有文件到 rootfs（排除 install.sh 自身）
$RK_RSYNC "${0%/*}/" "$TARGET_DIR/" --exclude install.sh

# 2. 创建 systemd 符号链接实现开机自启
mkdir -p "$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/watchdog.service "$TARGET_DIR/etc/systemd/system/multi-user.target.wants/"
ln -sf /etc/systemd/system/rebootcheck.service "$TARGET_DIR/etc/systemd/system/multi-user.target.wants/"
```

> 详细步骤参考 `rootfs_mount_guide.md` 第二章节。

#### 添加新 overlay 的步骤

1. 在 `overlays/rootfs/` 下创建子目录，按板端目标路径组织文件
2. 编写 `install.sh`（rsync 文件 + systemd 符号链接）
3. `chmod +x install.sh`
4. 执行 `./build.sh all` 重新编译打包，overlay 即自动生效

#### 仅 overlay 变更时的快速打包

若仅 overlay 内容变更（无需重编 U-Boot 和内核），可直接执行：

```bash
cp ubuntu/rootfs/rootfs.img ubuntu/rockchip/output/Image/
cd ubuntu/rockchip && ./mkimage.sh pack
```

### 交叉编译工具链（备选）

编译脚本已自动设置工具链，如需手动设置，可执行以下命令：

#### 1. U-Boot 和内核编译工具链
```bash
export PATH=/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
```

#### 2. 应用编译工具链
```bash
source /media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/environment
make CC=aarch64-linux-gnu-gcc
```
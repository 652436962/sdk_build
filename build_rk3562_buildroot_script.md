# RK3562 Buildroot SDK Docker 编译环境完整使用文档
**适用系统**：Ubuntu 20.04.6
**适用平台**：瑞芯微 RK3562 系列开发板（创龙），Buildroot 文件系统
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言
本文专为瑞芯微 RK3562 **Buildroot** SDK 编译打造，基于 Docker 搭建 Ubuntu 20.04 标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

> **说明**：RK3562 有两套 SDK：一套使用 Ubuntu rootfs（`build_rk3562_script.md`），另一套使用 Buildroot rootfs（本文档）。两者的 SDK 目录结构、编译命令均有差异，请确认使用的是 Buildroot 版本后再参考本文档。

---

## 一、前期准备
### 1.1 前提条件
1. 本机系统：Ubuntu 20.04.6（推荐纯净系统，无冗余软件源冲突）
2. RK3562 Buildroot 完整 SDK 已解压完成，**存放路径无中文、空格、特殊字符**
3. 网络正常，可拉取 Docker 镜像、下载系统依赖包

### 1.2 SDK 结构说明
Buildroot SDK 位于以下路径，目录结构如下：

**SDK 根目录**：[`rk3562_buildroot/rk3562_linux_sdk_release/`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release)

| 目录/文件 | 说明 |
| --------- | ---- |
| `app` | 存放上层应用 Demo |
| `buildroot` | Buildroot 根文件系统源码 |
| `build.sh` | 一键编译脚本 |
| `device/rockchip` | 芯片板级配置及打包脚本 |
| `kernel` | kernel-5.10 软链接 |
| `kernel-5.10` | Linux 内核源码（Linux-5.10.209） |
| `prebuilts` | 交叉编译工具链 |
| `rkbin` | Rockchip 二进制和工具 |
| `u-boot` | U-Boot-2017.09 源码 |
| `rockdev` | 编译输出目录（编译后生成） |

### 1.3 安装 Docker（仅执行一次）
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

### 1.4 SDK 目录权限修复（仅执行一次）
进入 RK3562 Buildroot SDK 根目录，修复文件权限，避免编译时报读写权限错误：
```bash
# 进入 SDK 根目录
cd /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release
# 修复目录归属（推荐）
sudo chown -R $USER:$USER .
# 备用命令（上一条命令报错时使用）
# sudo chmod -R 777 .
```

---

## 二、进入 Docker 编译环境
### 2.1 启动容器命令（首次执行）
**先进入本机 RK3562 Buildroot SDK 根目录**，再执行以下命令，自动进入编译容器：
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release

docker run -it \
--name rk3562_buildroot \
-v $(pwd):/workspace \
-w /workspace \
-h rk3562-br-build \
ubuntu:20.04 \
/bin/bash
```

> **注意**：此处已移除 `--rm` 参数，用于保留容器环境，避免每次重复安装依赖。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name rk3562_buildroot` | 容器命名，区分开发板型号与文件系统类型 |
| `-v $(pwd):/workspace` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /workspace` | 容器内默认进入 SDK 工作目录 |
| `-h rk3562-br-build` | 设置容器主机名，方便识别 |

### 2.3 重新进入已存在的容器
查看容器命令：
```bash
docker ps -a
```

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
docker start rk3562_buildroot
docker exec -it rk3562_buildroot /bin/bash
```

环境就绪标识：终端提示符变为
`root@rk3562-br-build:/workspace#`

---

## 三、安装编译依赖（仅首次进入容器安装）
### 3.1 安装系统依赖包
在 Docker 容器内执行以下命令，一键安装 RK3562 Buildroot SDK 全部编译依赖：
```bash
# 设置时区（避免 tzdata 安装卡住）
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 更新软件源并安装依赖
apt update && apt-get install -y \
git ssh make gcc libssl-dev \
liblz4-tool expect expect-dev g++ patchelf chrpath gawk texinfo chrpath \
diffstat binfmt-support qemu-user-static live-build bison flex fakeroot \
cmake gcc-multilib g++-multilib unzip device-tree-compiler ncurses-dev \
libgucharmap-2-90-dev bzip2 expat gpgv2 cpp-aarch64-linux-gnu libgmp-dev \
libmpc-dev bc python-is-python3 python2 libpkgconf-dev rsync bsdmainutils \
sudo xxd
```

> **说明**：`rsync` 和 `bsdmainutils`（包含 hexdump）是打包固件镜像时的必需依赖。

### 3.2 创建 python 符号链接
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

### 3.3 解压 Buildroot dl 压缩包（加快编译）
`dl.tar.gz` 存放从官网下载的开源软件包，在编译 Buildroot 时可从该目录获取源码包，避免因网络环境差异导致编译失败，大幅缩短编译时间。

将 `dl.tar.gz` 拷贝至 SDK 的 `buildroot/` 目录下并解压：
```bash
# 将 dl.tar.gz 拷贝至 buildroot/ 目录（在本机执行）
# cp /path/to/dl.tar.gz /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/buildroot/

# 在容器内解压
cd /workspace/buildroot
tar -zxf dl.tar.gz
```

### 3.4 添加脚本执行权限
```bash
chmod +x /workspace/build.sh
```

### 3.5 创建非 root 用户（解决编译权限问题）
编译脚本会通过 `sudo -u #UID` 降低权限编译内核，容器中必须有对应 UID 的用户。先查看 SDK 目录属主 UID，再创建同名用户：
```bash
# 查看 SDK 目录属主 UID（通常为 1000）
stat -c %u /workspace/build.sh

# 创建对应 UID 的用户（以 UID 1000 为例）
useradd -u 1000 -m builduser
echo 'builduser ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
```

---

## 四、SDK 编译指令
### 4.1 配置编译选项（编译前必须执行）
在 Docker 容器内，先配置 LinuxSDK 编译选项：
```bash
./build.sh tl3562_evm_defconfig
```

### 4.2 全量编译（推荐，生成完整刷机固件）
> **注意**：编译 buildroot 时 configure 脚本会检测到以 root 身份运行并拒绝执行，必须先设置环境变量 `FORCE_UNSAFE_CONFIGURE=1`。

```bash
export FORCE_UNSAFE_CONFIGURE=1
./build.sh
```

编译时长：约 2 小时（取决于 CPU 核心数与内存，首次编译需下载源码包可能更久）
**固件输出路径**：`rockdev/` 目录

编译完成后生成的主要镜像文件：

| 镜像文件 | 说明 |
| -------- | ---- |
| `boot.img` | 内核镜像，包含内核和设备树 |
| `MiniLoaderAll.bin` | DDR 初始化镜像和 U-Boot SPL 镜像 |
| `misc.img` | misc 镜像 |
| `oem.img` | oem 镜像，挂载至 `/oem` 目录 |
| `parameter.txt` | 分区表 |
| `recovery.img` | Recovery 镜像 |
| `rootfs.img` | Buildroot 文件系统镜像 |
| `uboot.img` | U-Boot 镜像 |
| `userdata.img` | userdata 镜像，挂载至 `/userdata` 目录 |
| **`update.img`** | **Linux 系统镜像（包含以上所有镜像）** |

### 4.3 局部编译
如需单独编译 U-Boot、内核或文件系统，可参照以下命令：

```bash
# 仅编译 U-Boot
./build.sh uboot
# 编译完成后在 rockdev/ 目录生成 MiniLoaderAll.bin 和 uboot.img

# 仅编译内核
./build.sh kernel
# 编译完成后在 rockdev/ 目录生成 boot.img

# 仅编译文件系统（Buildroot）
./build.sh buildroot
# 编译完成后在 rockdev/ 目录生成 rootfs.img

# 打包固件镜像（单独编译各模块后重新打包 update.img）
./build.sh firmware
# 编译完成后在 rockdev/ 目录生成 update.img
```

> **备注**：如需替换 U-Boot、内核、文件系统镜像，可替换 `output/firmware/` 目录下对应的镜像，再执行 `./build.sh firmware` 重新生成 `update.img`。

---

## 五、配置说明
### 5.1 配置设备树
默认编译的设备树文件为 `tl3562-evm.dts`，路径：
[`kernel/arch/arm64/boot/dts/rockchip/tl3562-evm.dts`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/kernel/arch/arm64/boot/dts/rockchip/tl3562-evm.dts)

SDK 中提供的设备树文件：

| 文件 | 说明 |
|------|------|
| `tl3562-evm.dts` | 默认设备树，支持基本外设（网口、USB、UART、GPIO、eMMC、SD 卡、音频等） |
| `tl3562-evm-mipi-lcd.dts` | 支持 MIPI LCD 显示，不支持 HDMI OUT |
| `tl3562-evm-lvds-lcd.dts` | 支持 LVDS LCD 显示，不支持 HDMI OUT |
| `tl3562-evm-sdio-wifi.dts` | 支持 SDIO WIFI，不支持 5G |
| `tl3562-evm-bluetooth-audio.dts` | 支持蓝牙音频设备 |

如需切换设备树，修改配置文件：
```bash
vi device/rockchip/rk3562/tl3562_evm_defconfig
```

修改内容：
```
#RK_KERNEL_DTS_NAME="tl3562-evm"           # 注释默认设备树
RK_KERNEL_DTS_NAME="tl3562-evm-mipi-lcd"   # 添加目标设备树
```

修改后重新配置并编译：
```bash
./build.sh tl3562_evm_defconfig
./build.sh kernel
```

### 5.2 配置内核选项（图形化）
```bash
./build.sh kernel-config
```

配置完毕后，选中 `<Save>` 保存，配置将自动保存到：
[`kernel/arch/arm64/configs/rockchip_linux_defconfig`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/kernel/arch/arm64/configs/rockchip_linux_defconfig)

### 5.3 配置 Buildroot 选项（图形化）
Buildroot 配置需先设置环境变量再打开图形界面：
```bash
cd /workspace/buildroot

# 使用 source 方式在当前 shell 中设置环境（避免 envsetup.sh 启动新 shell 导致后续命令无法执行）
source ./envsetup.sh rockchip_rk3562

# 打开 Buildroot 图形配置界面
make menuconfig
```

配置完毕后保存并退出，执行以下命令保存配置至 defconfig：
```bash
make savedefconfig
```

> **注意**：
> - `envsetup.sh` 必须使用 `source`（或 `.`）方式执行，若直接 `./envsetup.sh` 执行会启动新的 bash 子 shell，导致后续 `make menuconfig` 无法在当前 shell 中执行。
> - Buildroot 图形化配置需要交互式终端。若在 Docker 非交互模式下失败，可在本机系统操作，或直接编辑配置文件：
> [`buildroot/configs/rockchip_rk3562_defconfig`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/buildroot/configs/rockchip_rk3562_defconfig)

---

## 六、rootfs 根文件系统修改说明
> **注意**：以下 rootfs 镜像挂载/修改操作需在**本机**执行（需要 `sudo mount` 权限和 loop 设备支持），不要在 Docker 容器内操作。

### 6.1 挂载修改 rootfs.img（简要）
如需修改已编译好的 rootfs.img 文件系统镜像（在本机执行）：
```bash
# 创建挂载目录
mkdir -p ~/mount_dir

# 挂载 rootfs.img
sudo mount -o loop rootfs.img ~/mount_dir

# 挂载 proc（如需 chroot）
sudo mount -t proc /proc ~/mount_dir/proc

# 进入 chroot 环境修改文件
sudo chroot ~/mount_dir

# 退出并卸载
exit
sudo umount -l ~/mount_dir
```

> **详细操作参考**：[`rk3562_buildroot/Linux系统使用手册.md`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/Linux系统使用手册.md) 第 3 章

### 6.2 扩大 rootfs 镜像空间
若根文件系统剩余空间不足，可扩大镜像容量，详细操作参见使用手册第 3.2 节。

### 6.3 从 rootfs.img 提取 rootfs.tar.gz
```bash
sudo mount -o loop rootfs.img ~/mount_dir
sudo tar -czf rootfs.tar.gz -C ~/mount_dir/ .
sudo umount -l ~/mount_dir
```

### 6.4 通过 rootfs.tar.gz 制作 rootfs.img
```bash
dd if=/dev/zero of=rootfs.img bs=1G count=1
mkfs.ext4 rootfs.img
sudo mount -o loop rootfs.img ~/mount_dir
sudo tar -zxf rootfs.tar.gz -C ~/mount_dir
sudo umount -l ~/mount_dir
```

---

## 七、退出与重新进入
### 7.1 退出容器
容器内执行 `exit`，本机 SDK 文件不受影响：
```bash
exit
```

### 7.2 下次编译流程
1. 进入本机 SDK 根目录：
   ```bash
   cd /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release
   ```
2. 重新进入已存在的容器：
   ```bash
   docker start rk3562_buildroot
   docker exec -it rk3562_buildroot /bin/bash
   ```
3. 直接执行编译命令，**无需重复安装依赖**

---

## 八、固件烧写与板端验证
### 8.1 烧写工具
使用 Rockchip 官方 `upgrade_tool` 通过 USB 烧写固件：
```bash
# 工具路径（系统已安装）
which upgrade_tool          # /usr/local/bin/upgrade_tool
```

### 8.2 设备进入烧写模式

| 模式 | 说明 | 进入方法 |
|------|------|----------|
| Maskrom | 芯片内部 ROM 启动 | 断电 → 按住 RECOVERY → 上电 → 2 秒后松键 |
| Loader | 引导加载器模式 | 系统内执行 `reboot loader` |

### 8.3 烧写统一固件
```bash
# 1. 检查设备连接
sudo upgrade_tool LD
# 预期输出：List of rockusb connected(1) ... Mode=Maskrom

# 2. 烧写 update.img（全量烧写）
sudo upgrade_tool uf /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/rockdev/update.img

# 预期输出：
# Download Firmware Start
# Download Image... (100%)
# Download Firmware Success
# Upgrade firmware ok.
```

> 烧写完成后设备会自动重启进入新系统。

### 8.4 分步烧写（仅更新特定分区）
若只需更新部分分区镜像，避免全量烧写：
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/rockdev/

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

### 8.5 板端 SSH 验证
设备启动后通过 SSH 登录验证：
```bash
# 板端 IP：192.168.10.22
ssh root@192.168.10.22
```

**验证项**：
```bash
# 主机名
cat /etc/hostname

# 内核版本
cat /proc/version

# 内存信息
cat /proc/meminfo
```

---

## 九、常见问题与修复

### 9.1 Docker 拉取镜像失败
**现象**：
```
Error response from daemon: Get https://registry-1.docker.io/v2/: dial tcp: lookup registry-1.docker.io: no such host
```

**修复方法**：
```bash
sudo tee /etc/docker/daemon.json <<EOF
{
"registry-mirrors": ["https://ccr.ccs.tencentyun.com/"]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 9.2 缺少 python 命令
**现象**：
```
/usr/bin/env: 'python': No such file or directory
```

**修复方法**（容器内执行）：
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

### 9.3 权限问题
**现象**：
```
permission denied
```

**修复方法**（本机执行）：
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release
sudo chown -R $USER:$USER .
```

### 9.4 编译前未配置 defconfig
**现象**：执行 `./build.sh` 后报错找不到配置

**修复方法**：先执行配置命令：
```bash
./build.sh tl3562_evm_defconfig
```

### 9.5 Buildroot 编译下载失败
**现象**：编译 Buildroot 时下载源码包失败或卡住

**原因**：部分开源软件包需从外网下载，网络不稳定导致。

**修复方法**：确保已正确解压 `dl.tar.gz` 至 `buildroot/` 目录（参见第 3.3 节），该压缩包包含预下载的源码包，可避免网络下载。

### 9.6 应用开发环境冲突
**现象**：配置应用开发环境变量后再编译 LinuxSDK 失败

**原因**：应用开发环境的 sysroot（`buildroot/output/` 目录）与全量编译冲突。

**修复方法**：编译 LinuxSDK 前删除 `output` 目录：
```bash
rm -rf /workspace/buildroot/output
```

### 9.7 sudo 用户不存在（内核编译失败）
**现象**：
```
sudo: unknown user: #1000
ERROR: Running mk-kernel.sh - run_command failed!
```

**原因**：编译脚本通过 `sudo -u #UID` 降低权限编译内核，容器内缺少对应 UID 的用户。

**修复方法**：以 SDK 目录属主 UID 创建用户（通常为 1000）：
```bash
useradd -u 1000 -m builduser
echo 'builduser ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
```

### 9.8 Buildroot configure 拒绝以 root 运行
**现象**：
```
configure: error: you should not run configure as root
(set FORCE_UNSAFE_CONFIGURE=1 in environment to bypass this check)
```

**修复方法**：编译前设置环境变量：
```bash
export FORCE_UNSAFE_CONFIGURE=1
```

### 9.9 xxd 命令未找到
**现象**：
```
/bin/sh: 1: xxd: not found
```

**修复方法**（容器内执行）：
```bash
apt-get install -y xxd
```

---

## 十、注意事项
1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. 首次编译前必须执行 `./build.sh tl3562_evm_defconfig` 配置编译选项
3. 建议将 `dl.tar.gz` 解压至 `buildroot/` 目录，大幅缩短编译时间并避免网络下载失败
4. 禁止执行 `sudo apt upgrade` 等系统升级命令，避免破坏编译环境
5. 如需彻底删除容器重建环境，执行：
   ```bash
   docker stop rk3562_buildroot && docker rm rk3562_buildroot
   ```
6. 出现 `Permission denied` 权限报错，回到本机执行 1.4 节权限修复命令
7. Docker 安装后必须注销重登，否则无法正常使用容器
8. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
9. 单独编译 Buildroot 前请确认已解压 `dl.tar.gz`，且未配置应用开发环境变量

---

## 快捷操作总结（一键记忆）

### 首次使用（创建容器并安装依赖）
```bash
# 1. 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release

# 2. 启动 Docker 容器（首次创建）
docker run -it --name rk3562_buildroot \
  -v $(pwd):/workspace -w /workspace -h rk3562-br-build \
  ubuntu:20.04 /bin/bash

# 3. 设置时区
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 4. 安装编译依赖
apt update && apt-get install -y git ssh make gcc libssl-dev liblz4-tool \
  expect expect-dev g++ patchelf chrpath gawk texinfo diffstat \
  binfmt-support qemu-user-static live-build bison flex fakeroot cmake \
  gcc-multilib g++-multilib unzip device-tree-compiler ncurses-dev \
  libgucharmap-2-90-dev bzip2 expat gpgv2 cpp-aarch64-linux-gnu \
  libgmp-dev libmpc-dev bc python-is-python3 python2 libpkgconf-dev \
  rsync bsdmainutils sudo xxd

# 5. 创建非 root 用户（编译脚本 sudo 降权需要）
useradd -u 1000 -m builduser
echo 'builduser ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# 6. 创建 python 符号链接
ln -sf /usr/bin/python3 /usr/bin/python

# 7. 添加执行权限
chmod +x build.sh

# 8. 解压 dl.tar.gz（加快编译）
cd /workspace/buildroot && tar -zxf dl.tar.gz && cd /workspace

# 9. 配置编译选项
./build.sh tl3562_evm_defconfig

# 10. 开始编译
export FORCE_UNSAFE_CONFIGURE=1
./build.sh

# 11. 退出
exit
```

### 后续使用（直接进入已存在容器）
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release
docker start rk3562_buildroot
docker exec -it rk3562_buildroot /bin/bash
./build.sh
```


### 烧写固件到板端
```bash
# 1. 设备断电 → 按住 RECOVERY → 上电 → 2 秒后松键（进入 Maskrom）
# 2. 烧写
sudo upgrade_tool uf /media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/rockdev/update.img
# 3. 设备自动重启
```

> **固件输出位置**：`/media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/rockdev/update.img`

---

## 附录

### 设备树说明
内核默认编译的设备树为 **tl3562-evm**，支持 TL3562-EVM 开发板的基本外设（网口、USB、UART、GPIO、eMMC、SD 卡、音频等）。

**关键文件路径**：

| 文件类型 | 路径 |
|---------|------|
| 默认设备树（DTS） | [`kernel/arch/arm64/boot/dts/rockchip/tl3562-evm.dts`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/kernel/arch/arm64/boot/dts/rockchip/tl3562-evm.dts) |
| 内核 defconfig | [`kernel/arch/arm64/configs/rockchip_linux_defconfig`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/kernel/arch/arm64/configs/rockchip_linux_defconfig) |
| Buildroot defconfig | [`buildroot/configs/rockchip_rk3562_defconfig`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/buildroot/configs/rockchip_rk3562_defconfig) |
| 板级 defconfig | [`device/rockchip/rk3562/tl3562_evm_defconfig`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/device/rockchip/rk3562/tl3562_evm_defconfig) |

### 交叉编译工具链
编译脚本已自动设置工具链，路径如下：

| 类型 | 路径 |
|------|------|
| U-Boot / 内核编译 | `prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/` |
| 应用编译（Buildroot） | `buildroot/output/rockchip_rk3562/host/bin/`（需先编译 Buildroot 后生成） |

手动设置内核/U-Boot 工具链：
```bash
export PATH=/workspace/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/:$PATH
```

手动设置应用编译环境（需先编译 Buildroot 后 `buildroot/output/` 目录才会生成）：
```bash
source /workspace/buildroot/output/rockchip_rk3562/host/environment-setup
```

---

**备注**：本文档适配创龙 RK3562 Buildroot SDK（基于 rk3562_linux_release_v1.2.0_20240620），Docker 环境与官方编译要求完全一致。更多系统使用细节请参考 [`rk3562_buildroot/Linux系统使用手册.md`](file:///media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/Linux系统使用手册.md)。

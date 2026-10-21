# 飞凌 OK3562 Ubuntu SDK Docker 编译环境完整使用文档
**适用系统**：Ubuntu 22.04（Docker 容器）
**适用平台**：瑞芯微 RK3562 系列开发板（飞凌 OK3562-C）
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言
本文专为飞凌 OK3562 Ubuntu SDK 编译打造，基于 Docker 搭建 Ubuntu 22.04 标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

> ⚠️ **两条关键约束（实测踩坑）**
> 1. **必须以「与 SDK 属主同 UID 的非 root 用户」执行 `./build.sh`**，以 root 编译会在内核模块安装阶段报 `Permission denied`（见 三、3.4 与 八、8.6）。
> 2. 若 buildroot 阶段报 `can't execute patchelf` / `GLIBC_2.38 not found`，需清理预编译 buildroot 输出后重建（见 八、8.7）。

---

## 一、前期准备
### 1.1 前提条件
1. 本机系统：Ubuntu 20.04 / 22.04（推荐纯净系统，无冗余软件源冲突）
2. OK3562 Ubuntu 完整 SDK 已就位，**存放路径无中文、空格、特殊字符**
3. 网络正常，可拉取 Docker 镜像、下载系统依赖包
4. 磁盘预留空间 ≥ 80GB（完整源码 + 编译产物 + `update.img`）

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
进入 OK3562 SDK 根目录，修复文件权限，避免编译时报读写权限错误：
```bash
# 进入 SDK 根目录（替换为你实际的 SDK 路径）
cd /media/lechi/linuxsdk/linuxsdk/ok3562_sdk
# 修复目录归属（推荐）
sudo chown -R $USER:$USER .
# 备用命令（上一条命令报错时使用）
# sudo chmod -R 777 .
```

### 1.4 源码解压
源码以分卷压缩包形式存放于 `1-源码/`，需先合并再解压：
```bash
cd /media/lechi/linuxsdk/linuxsdk/ok3562_sdk

# 校验分卷完整性（可选，推荐）
md5sum -c 1-源码/sdk_md5sum.txt

# 合并分卷（约 11.6GB）
cat 1-源码/OK3562-linux-source.tar.bz2.* > OK3562-linux-source.tar.bz2

# 解压（生成 OK3562-linux-source 目录，约 32GB）
tar -xvf OK3562-linux-source.tar.bz2
```
> 解压后归档内自带 `buildroot/output/*` 预编译产物与 `ubuntu/jammy-rootfs.img`，可显著加快首次编译。

---

## 二、进入 Docker 编译环境
### 2.1 启动容器命令（首次执行）
**先进入本机 OK3562 SDK 根目录**，再执行以下命令：

```bash
cd /media/lechi/linuxsdk/linuxsdk/ok3562_sdk

docker run -it --privileged \
--name ok3562-sdk \
-v $(pwd):/workspace \
-w /workspace \
-h ok3562-build \
ubuntu:22.04 \
/bin/bash
```

> **注意**：`--privileged` 参数必须添加，否则安装内核模块时挂载 `ubuntu/jammy-rootfs.img` 会报 `Operation not permitted`。
> 容器默认以 root 登录，仅用于安装依赖；**编译须切换到属主 UID 用户**（见 三、3.4）。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name ok3562-sdk` | 容器命名，区分开发板型号 |
| `--privileged` | 特权模式，用于镜像打包 / 挂载 loop 设备 |
| `-v $(pwd):/workspace` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /workspace` | 容器内默认进入 SDK 工作目录 |
| `-h ok3562-build` | 设置容器主机名，方便识别 |

### 2.3 重新进入已存在的容器
查看容器命令：
```bash
docker ps -a
```

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
docker start ok3562-sdk
docker exec -it ok3562-sdk /bin/bash
```

> **注意**：首次编译前需要设置时区（避免 tzdata 安装卡住），在容器内执行：
> ```bash
> ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
> echo 'Asia/Shanghai' > /etc/timezone
> ```

环境就绪标识：终端提示符变为
`root@ok3562-build:/workspace#`

---

## 三、安装编译依赖（仅首次进入容器安装）
在 Docker 容器内（root）执行以下命令，安装 OK3562 Ubuntu SDK 编译依赖：

```bash
# 更新 apt-get 下载源
export DEBIAN_FRONTEND=noninteractive
apt-get update

# 安装所有编译依赖（合并为一条命令）
apt-get install -y \
build-essential \
libncurses-dev \
lzop \
net-tools \
openssh-server \
vim \
git \
fakeroot \
ssh \
make \
gcc \
libssl-dev \
lz4 \
expect \
expect-dev \
g++ \
patchelf \
chrpath \
gawk \
texinfo \
diffstat \
binfmt-support \
qemu-user-static \
live-build \
bison \
flex \
cmake \
gcc-multilib \
g++-multilib \
unzip \
cpio \
bzip2 \
perl \
patch \
device-tree-compiler \
python3-pip \
libgmp-dev \
libmpc-dev \
libicu-dev \
bsdmainutils \
bc \
sudo \
time \
uuid-runtime \
rsync \
dosfstools \
mtools \
parted \
iproute2 \
kmod \
libyaml-dev \
scons \
u-boot-tools \
lib32stdc++6 \
lib32z1 \
file \
wget
```

> **说明**：
> - `build-essential` 提供编译程序必须软件包
> - `libncurses-dev` 用于生成基于文本的用户界面
> - `lz4` 供内核打包使用（`check-kernel.sh` 依赖）
> - `expect`（含 `unbuffer`）供 buildroot 使用
> - `cpio` / `unzip` 是 buildroot 宿主机必备依赖
> - `dosfstools mtools parted` 用于镜像分区与打包
> - `u-boot-tools device-tree-compiler` 用于 U-Boot / 设备树编译
> - `sudo` 是挂载镜像的必需工具
> - `rsync bsdmainutils` 是打包固件的必需工具

### 3.1 启用 32 位库（libc6:i386 依赖）
官方依赖包含 `libc6:i386`，Ubuntu 22.04 默认未启用 i386 架构：
```bash
dpkg --add-architecture i386
apt-get update
apt-get install -y libc6:i386
```

### 3.2 创建 python 符号链接
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

### 3.3 添加脚本执行权限
```bash
chmod +x /workspace/OK3562-linux-source/build.sh
```

### 3.4 创建与 SDK 属主同 UID 的编译用户（★关键，否则编译必失败）
构建脚本会以 `sudo -u #<SDK属主UID>` 降权编译内核，且安装内核模块时需 `sudo` 提权挂载镜像；**容器 `/etc/passwd` 中必须存在与 SDK 属主相同的 UID 用户**，且编译须以该用户（非 root）执行：
```bash
# 1) 查看 SDK 属主 UID（本机通常为 1000）
stat -c '%u:%g' /workspace/OK3562-linux-source

# 2) 创建同 UID 用户（以 1000 为例）并授予免密 sudo
useradd -u 1000 -m -s /bin/bash builduser
echo 'builduser ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# 3) 验证
grep ':1000:' /etc/passwd
sudo -u '#1000' id
```
> 若 SDK 属主 UID 不是 1000，请将上面的 `1000` 全部替换为实际 UID。

---

## 四、SDK 编译指令

> ⚠️ **以下所有编译命令都必须以 `builduser`（属主 UID 用户）身份执行，不可用 root**，否则内核模块安装会报 `Permission denied`（见 八、8.6）。
> 切换方式：
> ```bash
> # 方式一：容器内 root 下切换用户
> su - builduser
> # 方式二：直接从宿主机以指定 UID 进入容器
> docker exec -it -u 1000 ok3562-sdk bash
> ```

### 4.1 配置编译选项（编译前必须执行）
进入 SDK 目录后配置 `defconfig`：
```bash
cd /workspace/OK3562-linux-source
./build.sh defconfig:forlinx_ok3562_ubuntu22_defconfig
```
也可执行 `./build.sh all` 后在弹出菜单中输入 `6`：
```
1. OK3562-UP4-linux_defconfig
2. forlinx_defconfig
3. forlinx_ok3562_linux_defconfig
4. forlinx_ok3562_linux_mcu_defconfig
5. forlinx_ok3562_linux_rtos_defconfig
6. forlinx_ok3562_ubuntu22_defconfig
Which would you like? [1]: 6
```

### 4.2 全量编译（推荐，生成完整刷机固件）
```bash
./build.sh all
```
编译成功后，镜像生成在 `rockdev/`（软链至 `output/firmware/`）目录下：
```bash
ls rockdev
```
> ⚠️ `update.img`（约 5.8GB）为打包好、用于 OTG 或 TF 卡**完全烧写**的镜像；其它文件用于**分步烧写**。

编译时长：首次约 15~40 分钟（归档自带预编译产物；若需重建 buildroot 会再增加约 10~15 分钟）。
**编译成功标志**：日志出现 `Running 99-all.sh - build_all succeeded.`

### 4.3 单独编译各模块
```bash
# 设置 defconfig（若未配置）
./build.sh defconfig:forlinx_ok3562_ubuntu22_defconfig

# 仅编译 U-Boot（生成 u-boot/uboot.img、rk3562_spl_loader_v1.06.106.bin）
./build.sh uboot

# 仅编译内核（生成 kernel/boot.img）
./build.sh kernel

# 仅编译根文件系统（生成 buildroot/output/OK3562_Linux/image/rootfs.ext2）
./build.sh rootfs

# 仅编译 recovery
./build.sh recovery

# 打包固件镜像（生成 rockdev/update.img）
./build.sh updateimg
```
> ⚠️ **单独编译成功后 `update.img` 里的内核不会自动更新**。请分步烧写对应文件（`uboot.img` / `boot.img`），或重新执行 `./build.sh updateimg` 重新打包。

### 4.4 清除编译产物
```bash
./build.sh clean:kernel     # 清除 kernel
./build.sh clean:rootfs     # 清除 rootfs
./build.sh clean:recovery   # 清除 recovery
```
> ⚠️ **U-Boot 没有开源，只有镜像**（`u-boot/` 下仅 `imgs/` 预编译镜像与 `make.sh` 包装），因此不含 `clean:uboot`。

---

## 五、内核配置说明
### 5.1 方法一：直接修改配置文件
直接将配置写到内核默认配置文件 `kernel/arch/arm64/configs/OK3562_Linux_defconfig` 中：

```bash
CONFIG_USB_SERIAL_CH341=y
```

然后重新编译内核：
```bash
./build.sh kernel
```

### 5.2 方法二：图形化配置

> **注意**：图形化配置需要交互式终端，在 Docker 非交互模式下会失败。如需使用图形配置，请以交互方式进入容器（`docker exec -it`）后操作。

#### 方案A：使用 build.sh kconfig（推荐）
```bash
./build.sh kconfig
```
在弹出的图形界面中完成配置后保存退出，新配置会自动生成新的 `OK3562_Linux_defconfig`。

#### 方案B：进入内核目录手动配置
```bash
cd /workspace/OK3562-linux-source/kernel
make ARCH=arm64 menuconfig
```

#### 方案C：直接修改配置文件
直接编辑 `kernel/arch/arm64/configs/OK3562_Linux_defconfig`，添加配置项：
```bash
CONFIG_USB_SERIAL_CH341=y
```

#### 重新编译内核
```bash
./build.sh kernel
```

---

## 六、Buildroot（recovery）配置说明
> 本 SDK 系统根文件系统为 **Ubuntu**（`ubuntu/jammy-rootfs.img`），buildroot 仅用于生成 **recovery** 恢复镜像。

### 6.1 方法一：直接修改配置文件
将配置写到 `buildroot/configs/OK3562_Linux_recovery_defconfig` 中，然后重新编译：
```bash
./build.sh recovery
```

### 6.2 方法二：图形化配置

> **注意**：图形化配置需要交互式终端，在 Docker 非交互模式下会失败。如需使用图形配置，请以交互方式进入容器后操作。

#### 方案A：使用 build.sh buildroot-config（推荐）
```bash
./build.sh buildroot-config
```

#### 方案B：进入 buildroot 目录手动配置
```bash
cd /workspace/OK3562-linux-source/buildroot
make O=output/OK3562_Linux_recovery menuconfig
```

#### 重新编译 recovery
```bash
./build.sh recovery
```

### 6.3 常用配置项
| 配置项 | 说明 |
|--------|------|
| Target options | 目标架构选择（AARCH64） |
| Build options | 编译选项（并行编译数等） |
| Toolchain | 交叉编译工具链配置 |
| System configuration | 系统配置（主机名、root 密码等） |
| Kernel | 内核配置 |
| Target packages | 目标软件包选择 |

---

## 七、退出与重新进入
### 7.1 退出容器
容器内执行 `exit`，本机 SDK 文件不受影响：
```bash
exit
```

### 7.2 下次编译流程
1. 进入本机 SDK 根目录
   ```bash
   cd /media/lechi/linuxsdk/linuxsdk/ok3562_sdk
   ```
2. 执行以下命令重新进入已存在的容器：
   ```bash
   docker start ok3562-sdk
   docker exec -it ok3562-sdk /bin/bash
   ```
3. 切换到编译用户后直接执行编译命令，**无需重复安装依赖**：
   ```bash
   su - builduser
   cd /workspace/OK3562-linux-source
   ./build.sh all
   ```

---

## 八、常见问题与修复
### 8.1 Docker 拉取镜像失败
**现象**：
```
Error response from daemon: Get https://registry-1.docker.io/v2/: dial tcp: lookup registry-1.docker.io: no such host
```

**修复方法**：
```bash
# 配置 Docker 镜像加速（国内服务器推荐）
sudo tee /etc/docker/daemon.json <<EOF
{
"registry-mirrors": ["https://ccr.ccs.tencentyun.com/"]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 8.2 权限问题
**现象**：
```
permission denied
```

**修复方法**（本机执行）：
```bash
cd /media/lechi/linuxsdk/linuxsdk/ok3562_sdk
sudo chown -R $USER:$USER .
```

### 8.3 Python 命令不存在
**现象**：
```
/usr/bin/env: 'python': No such file or directory
```

**修复方法**：
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

### 8.4 缺少 32 位库（libc6:i386）
**现象**：安装依赖时提示 `libc6:i386` 无法定位。
**修复方法**：
```bash
dpkg --add-architecture i386 && apt-get update && apt-get install -y libc6:i386
```

### 8.5 编译中途报缺少工具
**现象**：编译过程中报缺包，按下表补齐后重新编译：

| 报错信息 | 缺失包 |
|----------|--------|
| `check-kernel.sh: lz4: command not found` / `Your lz4 is too old` | `lz4` |
| `Your unbuffer is missing` | `expect expect-dev` |
| `You must install 'cpio' on your build machine` | `cpio` |
| `You must install 'unzip' on your build machine` | `unzip` |

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get install -y lz4 expect expect-dev cpio unzip bzip2 perl patch
```

### 8.6 `Unknown source owner` 或内核模块安装 `Permission denied`（★最常见）
**现象**：
- 以 root 执行 `./build.sh all` 时报 `ERROR: Unknown source owner(1000)`，或
- 内核模块安装阶段报：
```
rm: cannot remove '.../ubuntu/rootfs_mnt/lib/modules/.../*.ko': Permission denied
make: *** [Makefile:1556: __modinst_pre] Error 1
```

**原因**：未以 SDK 属主 UID 用户编译。以 root 编译时，`kernel-helper` 会给 `KMAKE` 加上 `sudo -u #1000`，导致安装内核模块被降权为 1000，而去写 root 属主的挂载镜像 → 无权限。

**修复方法**：
1. 按 三、3.4 在容器内创建与 SDK 属主同 UID 的用户；
2. **改以该用户身份编译**：`su - builduser` 或 `docker exec -it -u 1000 ok3562-sdk bash`；
3. 若此前用 root 编译过，修正残留文件属主后再重编：
```bash
docker exec ok3562-sdk chown -R 1000:1000 /workspace/OK3562-linux-source
```

### 8.7 buildroot 阶段 `can't execute patchelf` / `GLIBC_2.38 not found`
**现象**：
```
Error: can't execute patchelf utility .../host/bin/patchelf
... version `GLIBC_2.38' not found ...
make: *** [Makefile:796: target-finalize] Error 1
```
**原因**：归档自带的 `buildroot/output/OK3562_Linux_recovery` 预编译 host 工具依赖较高版本 glibc（如 `GLIBC_2.38`），在 Ubuntu 22.04（glibc 2.35）容器中无法运行。

**修复方法**：清理该输出目录，让 buildroot 在容器内从源码重建（约 10~15 分钟）：
```bash
cd /workspace/OK3562-linux-source
rm -rf buildroot/output/OK3562_Linux_recovery
./build.sh all
```

### 8.8 编译卡住或内存不足
**现象**：编译过程中系统变卡或崩溃。

**修复方法**：
```bash
# 限制 Docker 容器内存使用（根据机器配置调整）
docker run -it --memory=8g ...
```

### 8.9 编译产物清理
```bash
# 清理编译产物（保留源码）
rm -rf buildroot/output
rm -rf rockdev/

# 清理 Buildroot 配置
cd buildroot
make clean
make distclean
```

---

## 九、注意事项
1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. **禁止以 root 执行 `./build.sh`**，必须以 SDK 属主 UID 用户编译（见 三、3.4）
3. **禁止执行 `sudo apt upgrade` 等系统升级命令**，避免破坏编译环境
4. 编译需要 **8GB 以上内存**，编译过程**不要关闭终端、不要中断进程**，否则固件损坏
5. 首次进入容器需要安装依赖，耗时较长，请耐心等待
6. 如需彻底删除容器重建环境，执行：
   ```bash
   docker stop ok3562-sdk && docker rm ok3562-sdk
   ```
7. `update.img` 为完整烧写镜像；单独编译产出的镜像不会自动并入 `update.img`
8. Docker 安装后**必须注销重登**，否则无法免 sudo 使用容器

---

## 快捷操作总结（一键记忆）
### 首次使用（创建容器并进入 → 装依赖 → 建用户 → 编译）
```bash
# 1. 进入 SDK 目录并解压源码
cd /media/lechi/linuxsdk/linuxsdk/ok3562_sdk
cat 1-源码/OK3562-linux-source.tar.bz2.* > OK3562-linux-source.tar.bz2
tar -xvf OK3562-linux-source.tar.bz2

# 2. 启动容器（需要 --privileged 参数）
docker run -it --privileged --name ok3562-sdk \
  -v /media/lechi/linuxsdk/linuxsdk/ok3562_sdk:/workspace -w /workspace \
  -h ok3562-build ubuntu:22.04 /bin/bash

# 3. 设置时区（避免 tzdata 安装卡住）
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 4. 安装编译依赖
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y build-essential libncurses-dev lzop net-tools \
  openssh-server vim git fakeroot ssh make gcc libssl-dev lz4 expect expect-dev \
  g++ patchelf chrpath gawk texinfo diffstat binfmt-support qemu-user-static \
  live-build bison flex cmake gcc-multilib g++-multilib unzip cpio bzip2 perl \
  patch device-tree-compiler python3-pip libgmp-dev libmpc-dev libicu-dev \
  bsdmainutils bc sudo time uuid-runtime rsync dosfstools mtools parted iproute2 \
  kmod libyaml-dev scons u-boot-tools lib32stdc++6 lib32z1 file wget
dpkg --add-architecture i386 && apt-get update && apt-get install -y libc6:i386

# 5. python 符号链接 + 脚本权限
ln -sf /usr/bin/python3 /usr/bin/python
chmod +x /workspace/OK3562-linux-source/build.sh

# 6. 创建与 SDK 属主同 UID 的编译用户（关键）
useradd -u 1000 -m -s /bin/bash builduser
echo 'builduser ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# 7. 以 builduser 身份编译（选择 6）
su - builduser
cd /workspace/OK3562-linux-source
./build.sh all
# 输出：rockdev/update.img（约 5.8GB）
```

### 下次使用（重新进入容器并编译）
```bash
cd /media/lechi/linuxsdk/linuxsdk/ok3562_sdk
docker start ok3562-sdk
docker exec -it ok3562-sdk /bin/bash
su - builduser
cd /workspace/OK3562-linux-source
./build.sh all
```

### 后台全量编译
```bash
docker exec -u 1000 ok3562-sdk bash -c "cd /workspace/OK3562-linux-source && ./build.sh defconfig:forlinx_ok3562_ubuntu22_defconfig"
docker exec -d -u 1000 ok3562-sdk bash -c "cd /workspace/OK3562-linux-source && ./build.sh all 2>&1 | tee build.log"
docker exec ok3562-sdk tail -f /workspace/OK3562-linux-source/build.log   # 成功标志：build_all succeeded
```

---

## 附录：交叉编译链位置
编译完成后，交叉编译链位于以下路径（容器内 `/workspace/OK3562-linux-source/`）：

| 类型 | 路径 |
|------|------|
| 驱动/内核/U-Boot 编译链 | `prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-` |
| 文件系统应用（QT等）编译链 | `/opt/aarch64-buildroot-linux-gnu_sdk-buildroot/usr/bin`（原厂工具链） |

> **说明**：内核/U-Boot 编译链由 `build.sh` 自动设置；应用编译链路径参见原厂文档 `datasheet/原厂编译文档/ok3562编译ubuntu_sdk.md`。

### 关键文件路径

| 文件类型 | 路径 |
|---------|------|
| 内核 defconfig | [`kernel/arch/arm64/configs/OK3562_Linux_defconfig`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/kernel/arch/arm64/configs/OK3562_Linux_defconfig) |
| 设备树（DTS） | [`kernel/arch/arm64/boot/dts/rockchip/OK3562-C-Linux.dts`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/kernel/arch/arm64/boot/dts/rockchip/OK3562-C-Linux.dts) |
| 设备树（Common DTSI） | [`kernel/arch/arm64/boot/dts/rockchip/OK3562-C-common.dtsi`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/kernel/arch/arm64/boot/dts/rockchip/OK3562-C-common.dtsi) |
| SDK 编译配置 defconfig | [`device/forlinx/ok3562/forlinx_ok3562_ubuntu22_defconfig`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/device/forlinx/ok3562/forlinx_ok3562_ubuntu22_defconfig) |
| Buildroot（recovery）defconfig | [`buildroot/configs/OK3562_Linux_recovery_defconfig`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/buildroot/configs/OK3562_Linux_recovery_defconfig) |
| U-Boot 镜像（未开源） | [`u-boot/imgs/uboot.img`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/u-boot/imgs/uboot.img)、[`u-boot/imgs/rk3562_spl_loader_v1.06.106.bin`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/u-boot/imgs/rk3562_spl_loader_v1.06.106.bin) |
| 分区参数 | [`device/forlinx/ok3562/parameter-ubuntu-fit.txt`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/device/forlinx/ok3562/parameter-ubuntu-fit.txt) |
| FIT 镜像描述 | [`device/forlinx/ok3562/boot.its`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/device/forlinx/ok3562/boot.its)、[`device/forlinx/ok3562/boot4recovery.its`](/media/lechi/linuxsdk/linuxsdk/ok3562_sdk/OK3562-linux-source/device/forlinx/ok3562/boot4recovery.its) |

# RK3568 Buildroot SDK Docker 编译环境完整使用文档
**适用系统**：Ubuntu 20.04.6
**适用平台**：瑞芯微 RK3568 系列开发板（飞凌 OK3568-C）
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言
本文专为瑞芯微 RK3568 Buildroot SDK 编译打造，基于 Docker 搭建 Ubuntu 20.04 标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

---

## 一、前期准备
### 1.1 前提条件
1. 本机系统：Ubuntu 20.04.6（推荐纯净系统，无冗余软件源冲突）
2. RK3568 Buildroot 完整 SDK 已解压完成，**存放路径无中文、空格、特殊字符**
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
进入 RK3568 Buildroot SDK 根目录，修复文件权限，避免编译时报读写权限错误：
```bash
# 进入 SDK 根目录（替换为你实际的 SDK 路径）
cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk
# 修复目录归属（推荐）
sudo chown -R $USER:$USER .
# 备用命令（上一条命令报错时使用）
# sudo chmod -R 777 .
```

---

## 二、进入 Docker 编译环境
### 2.1 启动容器命令（首次执行）
**先进入本机 RK3568 Buildroot SDK 根目录**，再执行以下命令，自动进入编译容器：

```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk

docker run -it --privileged \
--name rk3568_sdk \
-v $(pwd):/workspace \
-w /workspace \
-h rk3568-build \
ubuntu:20.04 \
/bin/bash
```

> **注意**：`--privileged` 参数必须添加，否则后续挂载镜像时会报 `Operation not permitted` 错误。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name rk3568_sdk` | 容器命名，区分开发板型号 |
| `-v $(pwd):/workspace` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /workspace` | 容器内默认进入 SDK 工作目录 |
| `-h rk3568-build` | 设置容器主机名，方便识别 |

### 2.3 重新进入已存在的容器
查看容器命令：
```bash
docker ps -a
```

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
docker start rk3568_sdk
docker exec -it rk3568_sdk /bin/bash
```

> **注意**：首次编译前需要设置时区（避免 tzdata 安装卡住），在容器内执行：
> ```bash
> ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
> echo 'Asia/Shanghai' > /etc/timezone
> ```

> **解决中文乱码**：如目录中文名显示乱码（如 `''$'\346\272\220\347\240\201''`），执行：
> ```bash
> # 安装中文语言包
> apt-get install -y locales
> 
> # 配置中文 locale
> sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
> sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen
> locale-gen
> 
> # 设置环境变量
> export LANG=zh_CN.UTF-8
> export LC_ALL=zh_CN.UTF-8
> ```

环境就绪标识：终端提示符变为
`root@rk3568-build:/workspace#`

---

## 三、安装编译依赖（仅首次进入容器安装）
在 Docker 容器内执行以下命令，安装 RK3568 Buildroot SDK 编译依赖：

```bash
# 更新 apt-get 下载源
export DEBIAN_FRONTEND=noninteractive
apt-get update

# 安装所有编译依赖（合并为一条命令）
apt-get install -y \
build-essential \
libncurses* \
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
liblz4-tool \
expect \
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
device-tree-compiler \
python3-pip \
python2 \
libgmp-dev \
libmpc-dev \
libicu-dev \
bsdmainutils \
bc \
sudo \
time \
uuid-runtime \
rsync
```

> **说明**：
> - `build-essential` 提供编译程序必须软件包
> - `libncurses*` 用于生成基于文本的用户界面
> - `lzop` 是基于 Lzo 库的压缩解压工具
> - `net-tools` 是网络配置工具
> - `python2` 是 U-Boot 编译必需的
> - `sudo` 是挂载镜像的必需工具
> - `time` 是打包 recovery 镜像的必需工具
> - `rsync` 是打包固件的必需工具

依赖安装完成后，给编译脚本添加执行权限：
```bash
chmod +x build.sh
```

如果需要修复 kconf 工具版本问题（GLIBC 版本不匹配），执行以下命令：
```bash
cd /workspace/OK3568-linux-source/buildroot/support/kconfig
make -f Makefile.br HOSTCC=gcc conf
cp conf /workspace/OK3568-linux-source/output/kconf/conf
```

创建 python 符号链接：
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

---

## 四、SDK 编译指令
在 Docker 容器内，直接执行编译命令，根据需求选择：

### 4.1 全量编译（编译 buildroot 推荐，生成完整刷机固件）

```bash
./build.sh
```

执行后会提示选择开发板芯片：
```
Pick a chip:

1. OK3568
2. rk3566_rk3568
3. rk3588
Which would you like? [1]: 1
```
输入 `1` 后按回车继续编译。

### 4.2 单独编译各模块
```bash
# 仅编译 U-Boot
./build.sh uboot
# 编译完成后将在 rockdev/ 目录生成 u-boot 相关镜像

# 仅编译内核
./build.sh kernel
# 编译完成后将生成内核镜像文件 boot.img 或 boot.tar

# 仅编译根文件系统
./build.sh buildroot
# 编译完成后将生成 rootfs.squashfs 或 rootfs.tar

# 编译 recovery
./build.sh recovery

# 打包固件镜像
./build.sh updateimg
```

编译时长：20~60 分钟（取决于 CPU 核心数与内存）
**固件输出路径**：SDK 根目录 `rockdev/` 或 `output/` 文件夹

---

## 五、内核配置说明
### 5.1 方法一：直接修改配置文件
直接将配置写到内核默认配置文件 `kernel/arch/arm64/configs/OK3568-C-linux_defconfig` 中：

```bash
CONFIG_USB_SERIAL_CH341=y
```

然后重新编译内核：
```bash
./build.sh kernel
```

### 5.2 方法二：图形化配置

> **注意**：图形化配置需要交互式终端，在 Docker 非交互模式下会失败。如需使用图形配置，建议在本机系统（非 Docker）环境下操作，或使用 `nconfig`/`xconfig` 替代方案。

#### 方案A：使用 build.sh kernel-config（推荐）
```bash
./build.sh kernel-config
```

#### 方案B：进入内核目录手动配置
```bash
需要先修改 `device/rockchip/common/scripts/mk-kernel.sh`，将 `#run command $KMAKE $RK_KERNEL_CFG $RK_KERNEL_CFG_FRAGMENTS` 注释掉：
cd /workspace/OK3568-linux-source/kernel
make menuconfig
# 或使用 nconfig（基于 ncurses，更稳定）
make nconfig
```

#### 方案C：直接修改配置文件
直接编辑 `kernel/arch/arm64/configs/OK3568-C-linux_defconfig`，添加配置项：
```bash
CONFIG_USB_SERIAL_CH341=y
```

#### 重新编译内核
```bash
./build.sh kernel
```

---

## 六、Buildroot 配置说明
### 6.1 方法一：直接修改配置文件
将配置写到 `buildroot/configs/OK3568_defconfig` 中：

```bash
BR2_PACKAGE_PYTHON3=y
BR2_PACKAGE_PYTHON3_PY_PYC=y
```

然后重新编译：
```bash
./build.sh buildroot
```

### 6.2 方法二：图形化配置

> **注意**：图形化配置需要交互式终端，在 Docker 非交互模式下会失败。如需使用图形配置，建议在本机系统（非 Docker）环境下操作。

#### 方案A：使用 build.sh buildroot-config（推荐）
```bash
./build.sh buildroot-config
```

#### 方案B：进入 buildroot 目录手动配置
```bash
需要先修改 `device/rockchip/common/scripts/mk-buildroot.sh`，将 `make -C "$BUILDROOT_DIR" O="$BUILDROOT_OUTPUT_DIR" ${BUILDROOT_BOARD}_defconfig` 注释掉：
cd /workspace/OK3568-linux-source/buildroot
make menuconfig
```

#### 方案B：直接修改配置文件
编辑 `buildroot/configs/OK3568_defconfig`，添加配置项：
```bash
BR2_PACKAGE_PYTHON3=y
BR2_PACKAGE_PYTHON3_PY_PYC=y
```

#### 重新编译 Buildroot
```bash
./build.sh buildroot
```

> **Tips**：如单独编译文件系统，并单独烧写后，发现显示界面中程序并没有正确添加，可将 `buildroot/configs/OK3568_defconfig` 中的 `BR2_PACKAGE_DWKEYBOARD=n` 配置项修改为 `y`，重新编译即可恢复正常。

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
   cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk
   ```
2. 执行以下命令重新进入已存在的容器：
   ```bash
   docker start rk3568_sdk
   docker exec -it rk3568_sdk /bin/bash
   ```
3. 直接执行编译命令，**无需重复安装依赖**

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
cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk
sudo chown -R $USER:$USER .
```

### 8.3 kconf 工具版本不匹配
**现象**：
```
/lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.33' not found
```

**修复方法**（容器内执行）：
```bash
cd /workspace/OK3568-linux-source/buildroot/support/kconfig
make -f Makefile.br HOSTCC=gcc conf
cp conf /workspace/OK3568-linux-source/output/kconf/conf
```

### 8.4 Python 命令不存在
**现象**：
```
/usr/bin/env: 'python': No such file or directory
```

**修复方法**：
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

### 8.5 buildroot-config 配置失败
**现象**：
```
/tmp/tmp.XXX/build/buildroot-config/conf: No such file or directory
ERROR: Running .../30-rootfs.sh - pre_build_hook failed!
```

**原因**：buildroot 尚未编译，conf 工具不存在。

**修复方法**（选择其一）：

**方法一：先执行一次全量编译**（推荐）
```bash
./build.sh
```

**方法二：手动进入 buildroot 目录配置**
```bash
cd /workspace/OK3568-linux-source/buildroot
make rockchip_rk3568_defconfig
make menuconfig
```

### 8.6 编译卡住或内存不足
**现象**：编译过程中系统变卡或崩溃

**修复方法**：
```bash
# 限制 Docker 容器内存使用（根据机器配置调整）
docker run -it --memory=8g ...
```

### 8.6 编译产物清理
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
2. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
3. 如需彻底删除容器重建环境，执行：
   ```bash
   docker stop rk3568_sdk && docker rm rk3568_sdk
   ```
4. 首次进入容器需要安装依赖，耗时较长，请耐心等待
5. Buildroot 编译会下载大量源码包，请确保网络稳定

---

## 快捷操作总结（一键记忆）
### 首次使用（创建容器并进入）
```bash
# 1. 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk

# 2. 启动容器（需要 --privileged 参数）
docker run -it --privileged --name rk3568_sdk \
  -v $(pwd):/workspace -w /workspace -h rk3568-build \
  ubuntu:20.04 /bin/bash

# 3. 设置时区（避免 tzdata 安装卡住）
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 4. 安装编译依赖
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y build-essential libncurses* lzop net-tools \
  openssh-server vim git fakeroot ssh make gcc libssl-dev liblz4-tool \
  expect g++ patchelf chrpath gawk texinfo diffstat binfmt-support \
  qemu-user-static live-build bison flex cmake gcc-multilib g++-multilib \
  unzip device-tree-compiler python3-pip python2 libgmp-dev libmpc-dev \
  libicu-dev bsdmainutils bc sudo time uuid-runtime rsync

# 5. 修复 kconf 工具（GLIBC 版本问题）
cd /workspace/OK3568-linux-source/buildroot/support/kconfig
make -f Makefile.br HOSTCC=gcc conf
cp conf /workspace/OK3568-linux-source/output/kconf/conf

# 6. 创建 python 符号链接
ln -sf /usr/bin/python3 /usr/bin/python

# 7. 添加脚本执行权限
chmod +x /workspace/OK3568-linux-source/build.sh

# 8. 执行编译
cd /workspace/OK3568-linux-source
./build.sh
```

### 下次使用（重新进入容器并编译）
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk
docker start rk3568_sdk
docker exec -it rk3568_sdk /bin/bash
cd /workspace/OK3568-linux-source
./build.sh
```

---

## 附录：交叉编译链位置
编译完成后，交叉编译链位于以下路径：

| 类型 | 路径 |
|------|------|
| 驱动/内核编译链 | `OK3568-linux-source/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-` |
| 文件系统应用（QT等）编译链 | `OK3568-linux-source/buildroot/output/OK3568/host/bin/aarch64-linux-` |

> **说明**：以上路径是执行 `./build.sh buildroot` 后的编译链生成位置。
> 如果使用预置 `host.tar.bz2` 方式编译整包，需在编译完成后再解开 `host.tar.bz2` 即可获得编译链。

### 关键文件路径

| 文件类型 | 路径 |
|---------|------|
| 内核 defconfig | `kernel/arch/arm64/configs/OK3568-C-linux_defconfig` |
|  | 路径：/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/kernel/arch/arm64/configs/OK3568-C-linux_defconfig |
| 设备树（DTS） | `kernel/arch/arm64/boot/dts/rockchip/OK3568-C-linux.dts` |
|  | 路径：/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/kernel/arch/arm64/boot/dts/rockchip/OK3568-C-linux.dts |
| 设备树 (Common DTSI) | `kernel/arch/arm64/boot/dts/rockchip/OK3568-C-common.dtsi` |
|  | 路径：/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/kernel/arch/arm64/boot/dts/rockchip/OK3568-C-common.dtsi |
| Buildroot defconfig | `buildroot/configs/OK3568_defconfig` |
|  | 路径：/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/buildroot/configs/OK3568_defconfig |
| U-Boot defconfig | `u-boot/configs/OK3568-C_defconfig` |
|  | 路径：/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/u-boot/configs/OK3568-C_defconfig |
| 分区参数 | `device/rockchip/ok3568/parameter-buildroot-fit.txt` |
|  | 路径：/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/device/rockchip/ok3568/parameter-buildroot-fit.txt |
| BoardConfig | `device/rockchip/ok3568/BoardConfig-ok3568.mk` |
|  | 路径：/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/device/rockchip/ok3568/BoardConfig-ok3568.mk |
| FIT 镜像描述 | `device/rockchip/ok3568/boot.its` |
|  | 路径：/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/device/rockchip/ok3568/boot.its |

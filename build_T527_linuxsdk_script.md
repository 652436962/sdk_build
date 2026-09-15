# T527 Linux SDK Docker 编译环境完整使用文档
**适用系统**：Ubuntu 20.04.6
**适用平台**：全志 T527 系列开发板（飞凌 OK527-C）
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言
本文专为飞凌 OK527-C 开发板的 Linux SDK（OKT527-linux-sdk）编译打造，基于 Docker 搭建 Ubuntu 20.04 标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

---

## 一、前期准备
### 1.1 前提条件
1. 本机系统：Ubuntu 20.04.6（推荐纯净系统，无冗余软件源冲突）
2. T527 Linux SDK 分卷压缩包已下载完整，**存放路径无中文、空格、特殊字符**
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

### 1.3 SDK 解压与目录权限修复（仅执行一次）
进入 T527 SDK 存放目录，校验、合并解压分卷源码包：

```bash
# 1、进入 SDK 上级目录（解压后 SDK 将位于该目录下）
cd /media/lechi/linuxsdk/linuxsdk/t527_sdk

# 2、（可选）清除旧的解压产物，避免重复解压冲突
sudo rm -rf OKT527-linux-sdk

# 3、md5 校验分卷完整性
cd Source
md5sum -c sdk_md5sum.txt

# 4、原地合并分卷并解压（生成 ./OKT527-linux-sdk1.3/）
cat OKT527-linux-sdk1.3.tar.bz2.* | tar jxv

# 5、将解压出的目录移动到上级并重命名（去除版本号，便于后续引用）
mv OKT527-linux-sdk1.3 ../OKT527-linux-sdk

# 6、修复目录归属
cd /media/lechi/linuxsdk/linuxsdk/t527_sdk
sudo chown -R $USER:$USER OKT527-linux-sdk
# 备用命令（上一条报错时使用）
# sudo chmod -R 777 OKT527-linux-sdk

# 7、验证解压结果
ls OKT527-linux-sdk/build.sh && echo "✅ SDK 解压成功"
```

> **说明**：
> - 解压命令 `cat ...tar.bz2.* | tar jxv` 严格遵循官方文档 `ok527编译linuxSDK.md` 语法
> - **注意**：分卷解压出的目录名为 `OKT527-linux-sdk1.3`（带版本号），需重命名为 `OKT527-linux-sdk`
> - **重新解压**：如果之前已解压但需要恢复原始状态，执行步骤 2 删除后重跑步骤 4、5
> - 解压后 SDK 根目录为 `/media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/`

---

## 二、进入 Docker 编译环境
### 2.1 启动容器命令（首次执行）
**先进入本机 T527 Linux SDK 根目录**，再执行以下命令，自动进入编译容器：

```bash
cd /media/lechi/linuxsdk/linuxsdk/t527_sdk

docker run -it --privileged \
--name t527_linuxsdk \
-v $(pwd):/workspace \
-w /workspace \
-h t527-build \
ubuntu:20.04 \
/bin/bash
```

> **注意**：`--privileged` 参数必须添加，否则后续挂载镜像时会报 `Operation not permitted` 错误。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name t527_linuxsdk` | 容器命名，区分开发板型号 |
| `-v $(pwd):/workspace` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /workspace` | 容器内默认进入 SDK 工作目录 |
| `-h t527-build` | 设置容器主机名，方便识别 |

### 2.3 重新进入已存在的容器
查看容器命令：
```bash
docker ps -a
```

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
docker start t527_linuxsdk
docker exec -it t527_linuxsdk /bin/bash
```

> **注意**：首次编译前需要设置时区（避免 tzdata 安装卡住），在容器内执行：
> ```bash
> ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
> echo 'Asia/Shanghai' > /etc/timezone
> ```

> **解决中文乱码**：如目录中文名显示乱码，执行：
> ```bash
> apt-get install -y locales
> sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
> sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen
> locale-gen
> export LANG=zh_CN.UTF-8
> export LC_ALL=zh_CN.UTF-8
> ```

环境就绪标识：终端提示符变为
`root@t527-build:/workspace#`

---

## 三、安装编译依赖（仅首次进入容器安装）
在 Docker 容器内执行以下命令，安装 OKT527 Linux SDK 编译依赖：

```bash
# 启用 i386 架构（编译 32 位兼容库依赖）
dpkg --add-architecture i386

# 更新 apt-get 下载源
export DEBIAN_FRONTEND=noninteractive
apt-get update

# 安装所有编译依赖
apt-get install -y \
    openssh-server vim git fakeroot \
    make automake autoconf libtool \
    libssl-dev bc dosfstools mtools parted \
    iproute2 kmod libyaml-dev device-tree-compiler \
    python flex bison build-essential u-boot-tools \
    libncurses-dev lib32stdc++6 lib32z1 libc6:i386 \
    time rsync unzip cpio patch wget curl \
    gawk gettext texinfo bsdmainutils
```

> **说明**：
> - `lib32stdc++6 lib32z1 libc6:i386` 是全志工具链运行所必需的 32 位兼容库
> - `python flex bison` 是内核与 U-Boot 编译的基础工具
> - `device-tree-compiler` 用于编译设备树
> - `u-boot-tools` 提供 mkimage 等打包工具

依赖安装完成后，建立 `python` 软链接（部分脚本调用裸 `python` 命令）：
```bash
ln -sf /usr/bin/python3 /usr/bin/python || true
```

进入 SDK 根目录并赋予脚本执行权限：
```bash
cd /workspace/OKT527-linux-sdk
chmod +x build.sh
```

---

## 四、SDK 编译指令
在 Docker 容器内，进入 SDK 根目录后选择编译方式：

```bash
cd /workspace/OKT527-linux-sdk
```

### 4.1 全量编译（推荐，生成完整刷机固件）

#### 4.1.1 选择平台配置
首次编译需先执行配置：
```bash
./build.sh config
```

按提示依次选择（linux_dev 选 `2. buildroot`，board 选 `4. okt527`）：
```
========ACTION List: mk_config ;========
options : 
All available linux_dev:
   0. bsp
   1. dragonboard
   2. buildroot
   3. debian
Choice [buildroot]: 2
All available board:
   0. OK527_UP4
   1. demo_linux_aiot
   2. demo_linux_aiot_nand
   3. demo_linux_aiot_spinand
   4. okt527
Choice [okt527]: 4
```

#### 4.1.2 执行全量编译
```bash
./build.sh 2>&1 | tee build.log
```

#### 4.1.3 打包生成镜像
```bash
./build.sh pack
```

**编译成功标识**：
```
Dragon execute image.cfg SUCCESS !
----------image is at----------
~/work/OKT527-linux-sdk/out/t527_linux_okt527_uart0.img
pack finish
```

**编译时长**：30~90 分钟（取决于 CPU 核心数与内存）
**固件输出路径**：`out/t527_linux_okt527_uart0.img`

### 4.2 单独编译各模块
```bash
# 仅编译内核（含设备树、boot.img）
./build.sh kernel
./build.sh pack

# 仅编译 U-Boot（uboot 不开源，编译时会报错可忽略）
./build.sh brandy
./build.sh pack

# 仅编译 buildroot 文件系统
cd buildroot/buildroot-202205
./build.sh
cd /workspace/OKT527-linux-sdk
./build.sh pack

# 仅编译测试程序
source .buildconfig
./platform/forlinx/build.sh

# 清除编译产物（不影响源码）
./build.sh clean
```

### 4.3 更换启动 logo
```bash
# 替换启动 logo（720x480 BMP 格式）
cp your-logo.bmp device/config/chips/t527/boot-resource/boot-resource/bootlogo.bmp

# 重新打包镜像
./build.sh pack
```
# 输出镜像目录
/media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/out
openixcli flash t527_linux_okt527_uart0.img
---

## 五、内核与文件系统配置
### 6.1 修改内核配置
直接编辑 defconfig：
```bash
vim kernel/linux-5.15/arch/arm64/configs/OKT527-C-Linux_defconfig
# 添加配置项，例如：
CONFIG_USB_SERIAL_CH341=y
```
然后重新编译内核：
```bash
./build.sh kernel
./build.sh pack
```

### 6.2 修改 Buildroot 配置
```bash
cd buildroot/buildroot-202205

# 读取当前配置
make OKT527-C-Linux_defconfig ARCH=arm64

# 进入图形界面修改
make menuconfig

# 保存为默认配置
cp ../../out/t527/okt527/buildroot/.config configs/OKT527-C-Linux_defconfig

# 重新编译
./build.sh
cd /workspace/OKT527-linux-sdk
./build.sh pack
```

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
   cd /media/lechi/linuxsdk/linuxsdk/t527_sdk
   ```
2. 重新进入已存在的容器：
   ```bash
   docker start t527_linuxsdk
   docker exec -it t527_linuxsdk /bin/bash
   ```
3. 进入 SDK 并直接编译，**无需重复安装依赖**：
   ```bash
   cd /workspace/OKT527-linux-sdk
   ./build.sh 2>&1 | tee build.log
   ./build.sh pack
   ```

---

## 八、常见问题与修复
### 8.1 Docker 拉取镜像失败
**现象**：
```
Error response from daemon: Get https://registry-1.docker.io/v2/: dial tcp: ...
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

### 8.2 权限问题
**现象**：`permission denied`

**修复方法**（本机执行）：
```bash
cd /media/lechi/linuxsdk/linuxsdk/t527_sdk
sudo chown -R $USER:$USER .
```

### 8.3 32 位兼容库未安装
**现象**：执行工具链时报 `bash: ...: No such file or directory` 或 `cannot execute binary file`

**修复方法**（容器内执行）：
```bash
dpkg --add-architecture i386
apt-get update
apt-get install -y lib32stdc++6 lib32z1 libc6:i386
```

### 8.4 Python 命令不存在
**现象**：`/usr/bin/env: 'python': No such file or directory`

**修复方法**：
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

### 8.5 U-Boot 编译报错
**现象**：执行 `./build.sh brandy` 报错

**说明**：U-Boot 源码不开源，单独编译时会报错，**忽略即可**，全量编译已包含预编译的 U-Boot。

### 8.6 编译卡住或内存不足
**修复方法**：
```bash
# 限制 Docker 容器内存使用（按机器配置调整）
docker run -it --memory=8g ...
```

### 8.7 编译产物清理
```bash
# 容器内清理（保留源码）
cd /workspace/OKT527-linux-sdk
./build.sh clean

# 彻底清理
rm -rf out/
```

---

## 九、注意事项
1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
3. 全量编译后必须执行 `./build.sh pack` 才能生成可烧录镜像
4. 如需彻底删除容器重建环境，执行：
   ```bash
   docker stop t527_linuxsdk && docker rm t527_linuxsdk
   ```
5. 首次进入容器需要安装依赖，耗时较长，请耐心等待
6. Buildroot 编译会下载大量源码包，请确保网络稳定
7. 部分无线驱动（RTL8852BS、XR829、AIC8800）与 Linux 5.15 存在兼容性问题，建议禁用
8. 打包镜像前需确保已安装 `busybox` 工具

---

## 快捷操作总结（一键记忆）
### 首次使用（创建容器并进入）
```bash
# 1. 解压 SDK 分卷
cd /media/lechi/linuxsdk/linuxsdk/t527_sdk/Source
cat OKT527-linux-sdk1.3.tar.bz2.* | tar jxv
mv OKT527-linux-sdk ../
cd /media/lechi/linuxsdk/linuxsdk/t527_sdk

# 2. 启动容器
docker run -it --privileged --name t527_linuxsdk \
  -v $(pwd):/workspace -w /workspace -h t527-build \
  ubuntu:20.04 /bin/bash

# 3. 设置时区
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 4. 安装编译依赖
dpkg --add-architecture i386
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y \
  openssh-server vim git fakeroot make automake autoconf libtool \
  libssl-dev bc dosfstools mtools parted iproute2 kmod libyaml-dev \
  device-tree-compiler python flex bison build-essential u-boot-tools \
  libncurses-dev lib32stdc++6 lib32z1 libc6:i386 sudo time rsync unzip \
  cpio patch wget curl gawk gettext texinfo bsdmainutils

# 5. python 符号链接
ln -sf /usr/bin/python3 /usr/bin/python

# 6. 进入 SDK 并配置
cd /workspace/OKT527-linux-sdk
chmod +x build.sh

# 7. 选择平台（linux / okt527 / default）
./build.sh config

# 8. 全量编译 + 打包
./build.sh 2>&1 | tee build.log
./build.sh pack
```

### 下次使用（重新进入容器并编译）
```bash
cd /media/lechi/linuxsdk/linuxsdk/t527_sdk
docker start t527_linuxsdk
docker exec -it t527_linuxsdk /bin/bash
cd /workspace/OKT527-linux-sdk
./build.sh 2>&1 | tee build.log
./build.sh pack
```

---

## 附录：关键文件路径说明
SDK 根目录 `OKT527-linux-sdk/` 下的关键配置文件：

| 文件类型 | 路径 |
|---------|------|
| 内核配置 | `buildroot/buildroot-202205/configs/OKT527-C-Linux_defconfig` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/buildroot/buildroot-202205/configs/OKT527-C-Linux_defconfig |
| 设备树（DTSI） | `bsp/configs/linux-5.15/sun55iw3p1.dtsi` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/bsp/configs/linux-5.15/sun55iw3p1.dtsi |
| 设备树（公共） | `kernel/linux-5.15/arch/arm64/boot/dts/allwinner/OKT527-C-Common.dtsi` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/kernel/linux-5.15/arch/arm64/boot/dts/allwinner/OKT527-C-Common.dtsi |
| 设备树（板级） | `kernel/linux-5.15/arch/arm64/boot/dts/allwinner/OKT527-C-Linux.dts` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/kernel/linux-5.15/arch/arm64/boot/dts/allwinner/OKT527-C-Linux.dts |
| sysconfig.fex | `device/config/chips/t527/configs/okt527/sys_config.fex` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/device/config/chips/t527/configs/okt527/sys_config.fex |
| 文件系统 overlay | `buildroot/buildroot-202205/board/forlinx/okt527/fs-overlay/` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/buildroot/buildroot-202205/board/forlinx/okt527/fs-overlay/ |
| Buildroot target | `out/t527/okt527/buildroot/buildroot/target/` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/out/t527/okt527/buildroot/buildroot/target/ |
| U-Boot 环境变量 | `device/config/chips/t527/configs/okt527/buildroot/env.cfg` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/device/config/chips/t527/configs/okt527/buildroot/env.cfg |
| 启动 logo | `device/config/chips/t527/boot-resource/boot-resource/bootlogo.bmp` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/device/config/chips/t527/boot-resource/boot-resource/bootlogo.bmp |

> **说明**：编译时 `fs-overlay/` 内的文件会覆盖 `target/` 内同路径同名文件，修改文件系统优先在 `fs-overlay/` 下操作。

### 测试程序源码路径
| 类型 | 子目录 |
|------|--------|
| 命令行测试程序 | `platform/forlinx/forlinx_cmd_demo/` |
| Qt 测试程序 | `platform/forlinx/forlinx_qt_demo/` |
| 脚本测试（wifi/ap/gpio） | `buildroot/buildroot-202205/board/forlinx/okt527/fs-overlay/usr/bin/fltest_*.sh` |

### 交叉编译链
| 类型 | 路径 |
|------|------|
| 内核编译链 | `OKT527-linux-sdk/out/toolchain/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-` |
| 应用编译链（Buildroot） | `OKT527-linux-sdk/out/t527/okt527/buildroot/buildroot/host/bin/aarch64-none-linux-gnu-` |

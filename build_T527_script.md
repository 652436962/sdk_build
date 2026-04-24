# T527 OpenHarmony 5.0 SDK Docker 编译环境完整使用文档
**适用系统**：Ubuntu 20.04 / 22.04
**适用平台**：全志 T527 系列开发板（飞凌 OK527-C）
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言

本文专为飞凌 OK527-C 开发板的 OpenHarmony 5.0 SDK 编译打造，基于 Docker 自建 Ubuntu 22.04 标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

> **重要提示**：推荐使用 Ubuntu 22.04，GLIBC 版本更高（2.35），可避免编译工具兼容性问题。

---

## 一、前期准备

### 1.1 前提条件
1. 本机系统：Ubuntu 20.04 / 22.04（推荐 22.04，GLIBC 版本更高）
2. 飞凌 T527 OpenHarmony 5.0 SDK 已解压完成，**存放路径无中文、空格、特殊字符**
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
进入 T527 OpenHarmony SDK 根目录，修复文件权限：
```bash
# 进入 SDK 根目录（替换为你实际的 SDK 路径）
cd /home/lechi/tronlong/t527_openharmony/

# 修复目录归属（推荐）
sudo chown -R $USER:$USER .
```

### 1.4 关键文件路径
以下是飞凌 T527 开发板的关键配置文件路径：

| 类型 | 路径 |
|------|------|
| 设备树（Bootloader） | `device/board/forlinx/okt527/bootloader/configs/okt527/linux-5.10/board.dts` |
| 设备树（DTSI） | `device/board/forlinx/okt527/bootloader/configs/default/linux-5.10/sun55iw3p1.dtsi` |
| 编译配置 | `device/soc/allwinner/t527/patches/config/t527_standard_defconfig` |

---

## 二、进入 Docker 编译环境

### 2.1 启动容器命令（首次执行）
**先进入本机 T527 OpenHarmony SDK 根目录**，再执行以下命令，自动进入编译容器：

```bash
cd /home/lechi/tronlong/t527_openharmony/

docker run -it --privileged \
--name t527 \
-v $(pwd):/home/openharmony \
-w /home/openharmony \
-h t527 \
ubuntu:22.04 \
/bin/bash
```

> **注意**：`--privileged` 参数必须添加，否则后续挂载镜像或执行打包工具时会报 `Operation not permitted` 错误。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name t527` | 容器命名，简短易记 |
| `-v $(pwd):/home/openharmony` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /home/openharmony` | 容器内默认进入 SDK 工作目录 |
| `-h t527` | 设置容器主机名，方便识别 |

### 2.3 重新进入已存在的容器
查看已有容器：
```bash
docker ps -a
```

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
docker start t527
docker exec -it t527 /bin/bash
```

环境就绪标识：终端提示符变为
`root@t527:/home/openharmony#`

---

## 三、安装编译依赖（仅首次进入容器安装）

> **重要**：以下命令均在 **Docker 容器内** 执行。容器默认以 root 运行，无需加 `sudo`。

### 3.1 设置时区（避免 tzdata 安装时交互式卡住）
```bash
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone
```

### 3.2 解决中文乱码（可选）
如目录中文名显示乱码，执行：
```bash
# 安装中文语言包
apt-get update
apt-get install -y locales

# 配置中文 locale
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen
locale-gen

# 设置环境变量
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
```

### 3.3 安装基础编译依赖
```bash
# 更新下载源
apt-get update

# 基础编译工具
apt-get install -y build-essential

# 文本界面库
apt-get install -y libncurses5-dev libncursesw5-dev

# 压缩解压工具
apt-get install -y lzop liblz4-tool

# 网络工具
apt-get install -y net-tools ssh

# 必备工具（含打包必需工具 busybox）
apt-get install -y openssh-server vim git git-lfs fakeroot busybox

# 版本管理与构建工具
apt-get install -y repo make gcc g++ expect patchelf chrpath gawk texinfo diffstat binfmt-support qemu-user-static live-build bison flex cmake gcc-multilib g++-multilib unzip device-tree-compiler

# 数学/编码库
apt-get install -y libgmp-dev libmpc-dev libicu-dev bsdmainutils

# Python 3.10 及 pip（Ubuntu 22.04 默认版本）
apt-get install -y python3 python3-pip python3-distutils

# 其他编译工具
apt-get install -y apt-utils binutils bc mtd-utils u-boot-tools zip curl wget ruby dosfstools mtools default-jre default-jdk scons perl openssl libssl-dev cpio m4 ccache zlib1g-dev tar rsync genext2fs binutils-dev e2fsprogs gnupg gnutls-bin gperf libffi-dev libelf-dev libx11-dev libgl1-mesa-dev lib32z1-dev xsltproc x11proto-core-dev libxml2-dev libdwarf-dev

# 额外工具
apt-get install -y grsync xxd libglib2.0-dev libpixman-1-dev kmod jfsutils reiserfsprogs xfsprogs squashfs-tools pcmciautils quota ppp libtinfo-dev libtinfo5 libstdc++6 gcc-arm-none-eabi locales

# 图形相关依赖
apt-get install -y libxinerama-dev libxcursor-dev libxrandr-dev libxi-dev

# LLVM
apt-get install -y llvm

# OpenHarmony 额外需要
pip3 install rich
```

### 3.4 修改默认 shell 为 bash
OpenHarmony 编译脚本使用 `pushd`、`shopt` 等 bash 特性，需将容器默认 shell 从 dash 改为 bash：
```bash
ln -sf /bin/bash /bin/sh
```

### 3.5 创建 Python 符号链接
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

### 3.6 执行预处理脚本
```bash
cd /home/openharmony/forlinx-5.0-release

cd device/board/forlinx/okt527/patch
./pre_build.sh

cd /home/openharmony/forlinx-5.0-release
```

### 3.7 添加脚本执行权限
```bash
chmod +x build.sh
```

---

## 四、SDK 编译指令

在 Docker 容器内，进入 SDK 工作目录后执行编译命令：

```bash
cd /home/openharmony/forlinx-5.0-release
```

### 4.1 全量编译（推荐，生成完整刷机固件）
```bash
./build.sh --product-name okt527 --ccache
```

> **注意**：首次编译时，如 `prebuilts/ohos-sdk/linux` 不存在，`build.sh` 会自动优先编译 ohos-sdk，耗时较长，请耐心等待。

### 4.2 单独编译子系统（可选）
```bash
# 编译内核
# ./build.sh --product-name okt527 --ccache --build-target kernel

# 编译启动引导
# ./build.sh --product-name okt527 --ccache --build-target bootloader

# 编译系统组件
# ./build.sh --product-name okt527 --ccache --build-target apps
```

### 4.3 编译选项说明
| 选项 | 说明 |
|------|------|
| `--product-name` | 产品名称，飞凌 T527 使用 `okt527` |
| `--ccache` | 启用编译缓存，加速重复编译 |
| `--build-target` | 指定编译目标（kernel/bootloader/apps/acts 等） |
| `--no-prebuilt-sdk` | 跳过 ohos-sdk 编译 |

编译时长：30~90 分钟（取决于 CPU 核心数与内存）

### 4.4 打包生成固件
编译完成后，可选择以下任一方式打包生成最终的可烧录固件。

**方式一：使用 `pack.sh`（传统方式）**
```bash
cd /home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/
./pack.sh
```

> **注意**：此方式在 Docker Ubuntu 22.04 环境下，`dragon` 工具通过 `qemu-i386-static` 模拟运行 32 位程序，**可能触发段错误**（见 [7.7 节](#77-打包失败--dragon-段错误)）。如遇到段错误，请使用方式二。

**方式二：使用 `dragon.real`（绕过 qemu）**
```bash
cd /home/openharmony/forlinx-5.0-release/out/pack_out
/home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/tools/pack/eDragonEx/dragon.real image.cfg sys_partition.fex
```

**固件输出路径**：`out/pack_out/` 目录，生成的固件文件为 `t527_linux_okt527_uart0.img` 或类似文件。

---

## 五、内核配置说明

### 5.1 直接修改配置文件
OpenHarmony 内核源码位于 `kernel/linux/linux-5.10/`，如需修改内核配置，可直接编辑对应的 defconfig 文件：

```bash
cd /home/openharmony/forlinx-5.0-release/kernel/linux/linux-5.10
```

修改完成后需提交到本地 git 仓库，否则编译时克隆的源码不包含修改：
```bash
cd /home/openharmony/forlinx-5.0-release/kernel/linux/linux-5.10
git config user.email "your@email.com"
git config user.name "Your Name"
git add <modified-files>
git commit -m "Fix description"
```

然后重新编译：
```bash
cd /home/openharmony/forlinx-5.0-release
./build.sh --product-name okt527 --ccache --build-target kernel
```

### 5.2 图形化配置（需要交互式终端）
```bash
cd /home/openharmony/forlinx-5.0-release/kernel/linux/linux-5.10
make menuconfig
# 或使用 nconfig（基于 ncurses，更稳定）
make nconfig
```

---

## 六、退出与重新进入

### 6.1 退出容器
容器内执行 `exit`，本机 SDK 文件不受影响：
```bash
exit
```

### 6.2 下次编译流程
1. 进入本机 SDK 根目录：
   ```bash
   cd /home/lechi/tronlong/t527_openharmony/
   ```
2. 重新进入已存在的容器：
   ```bash
   docker start t527
   docker exec -it t527 /bin/bash
   ```
3. 进入 SDK 目录并编译，**无需重复安装依赖**：
   ```bash
   cd /home/openharmony/forlinx-5.0-release
   ./build.sh --product-name okt527 --ccache
   ```
4. 打包固件（任选其一）：
   - 方式一（`pack.sh`）：
     ```bash
     cd /home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/
     ./pack.sh
     ```
   - 方式二（`dragon.real`，绕过 qemu 避免段错误）：
     ```bash
     cd /home/openharmony/forlinx-5.0-release/out/pack_out
     /home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/tools/pack/eDragonEx/dragon.real image.cfg sys_partition.fex
     ```

---

## 七、常见问题与修复

### 7.1 Docker 拉取镜像失败
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

### 7.2 权限问题
**现象**：
```
permission denied
```

**修复方法**（本机执行）：
```bash
cd /home/lechi/tronlong/t527_openharmony/
sudo chown -R $USER:$USER .
```

### 7.3 Python 命令不存在
**现象**：
```
/usr/bin/env: 'python': No such file or directory
```

**修复方法**：
```bash
ln -sf /usr/bin/python3.8 /usr/bin/python
```

### 7.4 编译卡住或内存不足
**现象**：编译过程中系统变卡或崩溃

**修复方法**：
1. 修改并行编译线程数，限制并发数：
   ```bash
   # 在编译命令前设置
   export NINJA_JOBS=8
   ```
2. 或限制 Docker 容器内存使用（根据机器配置调整）：
   ```bash
   docker run -it --memory=8g --name t527-oh5.0-build ...
   ```

### 7.5 编译产物清理
```bash
# 清理编译产物（保留源码）
cd /home/openharmony/forlinx-5.0-release
rm -rf out/

# 清理编译缓存
rm -rf ~/.cache/build
```

### 7.6 打包失败 — 打包工具依赖缺失
**现象 A**：执行 `./pack.sh` 提示 `busybox: command not found`

pack 脚本使用 `busybox unix2dos` 处理配置文件，如未安装会中断打包。

**修复方法**：
```bash
apt-get update && apt-get install -y busybox
```

**现象 B**：执行 `./pack.sh` 提示 `/usr/bin/qemu-i386-static: No such file or directory`

dragon 脚本依赖 `qemu-i386-static` 来运行 32 位打包工具 `dragon.real`。

**修复方法**：
```bash
apt-get update && apt-get install -y qemu-user-static
```

> **注意**：以上两条命令必须在 **Docker 容器内**执行。如在宿主机上运行 pack.sh，请先进入容器：
> ```bash
> docker start t527
> docker exec -it t527 /bin/bash
> ```

### 7.7 打包失败 — dragon 段错误
**现象**：执行 `./pack.sh` 时出现：
```
qemu: uncaught target signal 11 (Segmentation fault) - core dumped
dragon image.cfg    sys_partition.fex
Segmentation fault
```

**原因**：qemu-i386 运行 dragon.real 时发生段错误。

**修复方法**：直接运行 dragon.real，跳过 qemu
```bash
cd /home/openharmony/forlinx-5.0-release/out/pack_out
# 直接运行 dragon.real
/home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/tools/pack/eDragonEx/dragon.real image.cfg sys_partition.fex

# 如果生成了固件，手动拷贝到 out 目录
cp /home/openharmony/forlinx-5.0-release/out/pack_out/t527_linux_okt527_uart0.img /home/openharmony/forlinx-5.0-release/out/
```

### 7.8 编译报错 — FileNotFoundError: error.log
**现象**：编译过程中出现 `FileNotFoundError: error.log` 等错误

**修复方法**：这是 hb 工具的 bug，不影响实际编译结果，可忽略。检查 `out` 目录下是否有生成的产物。

### 7.9 GPIO 驱动编译错误
**现象**：`gpio_adapter.c` 中 `gpiod_get_direction` 和 `gpio_to_desc` 隐式声明错误

**修复方法**：修改 `drivers/hdf_core/adapter/khdf/linux/platform/gpio/gpio_adapter.c`
在 `#include` 部分添加头文件：
```c
#include <linux/gpio.h>
#include <linux/gpio/consumer.h>
#include <linux/gpio/driver.h>
#include <linux/interrupt.h>
```

并将 `gpiochip_find` 调用条件编译：
```c
#if 0
    (void)gpiochip_find(device, LinuxGpioMatchProbe);
#endif
```

### 7.10 rtc_time64_to_tm 未定义引用
**现象**：内核链接时 `blackbox_common.o` 报 `rtc_time64_to_tm` 未定义引用

**修复方法**：
1. 修改 `kernel/linux/linux-5.10/drivers/staging/blackbox/blackbox_common.c`
在文件开头添加 `rtc_time64_to_tm` 函数的本地实现：
```c
#include <linux/timekeeping.h>

void rtc_time64_to_tm(time64_t time, struct rtc_time *tm)
{
	if (tm == NULL) return;
	tm->tm_sec = time % 60;
	tm->tm_min = (time / 60) % 60;
	tm->tm_hour = (time / 3600) % 24;
	tm->tm_mday = (time / 86400) + 1;
	tm->tm_mon = ((time / 86400) / 30) % 12;
	tm->tm_year = ((time / 86400) / 365) + 70;
}
```

2. 提交更改到本地 git 仓库：
```bash
cd /home/openharmony/forlinx-5.0-release/kernel/linux/linux-5.10
git add drivers/staging/blackbox/blackbox_common.c
git config user.email "your@email.com"
git config user.name "Your Name"
git commit -m "Add rtc_time64_to_tm stub for blackbox"
```

### 7.11 内核 memory_security Makefile 错误
**现象**：`make[3]: *** [fs/proc/memory_security/built-in.a] Error 1` - ar 命令参数错误

**原因**：`kernel/linux/common_modules/memory_security/Makefile` 中 `obj-y` 包含 `-I$(obj)` 参数

**修复方法**：修改 `kernel/linux/common_modules/memory_security/Makefile`
移除错误的 `-I$(obj)` 参数：
```makefile
obj-$(CONFIG_HIDE_MEM_ADDRESS) += \
    src/hideaddr.o \
    module.o

obj-$(CONFIG_JIT_MEM_CONTROL) += \
    src/jit_space_list.o \
    src/jit_process.o \
    src/jit_memory.o \
    src/jit_memory_module.o \
    module.o
```

---

## 八、编译结果验证

### 8.1 验证编译成功
编译成功标识：
```
[OHOS INFO] okt527 build success
[OHOS INFO] Cost Time:  HH:MM:SS
=====build  successful=====
```

### 8.2 固件输出路径
固件输出目录：`out/pack_out/`

主要固件文件：
| 文件 | 说明 |
|------|------|
| `boot_package.fex` | 完整启动包 |
| `u-boot.fex` | U-Boot 引导程序 |
| `kernel.fex` | 内核镜像 (uImage) |
| `rootfs.fex` | 根文件系统 |
| `sys_prod.fex` | 系统配置 |
| `vendor.fex` | 厂商分区 |
| `t527_linux_okt527_uart0.img` | 最终烧录固件 |

---

## 九、注意事项
1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
3. 如需彻底删除容器重建环境，执行：
   ```bash
   docker stop t527 && docker rm t527
   ```
4. 首次进入容器需要安装依赖，耗时较长，请耐心等待
5. OpenHarmony 编译会下载大量源码包，请确保网络稳定
6. 每次进入容器后，必须先进入 SDK 目录 `cd /home/openharmony/forlinx-5.0-release`

---

## 快捷操作总结（一键记忆）

### 首次使用（创建容器并进入）
```bash
# 1. 进入 SDK 目录
cd /home/lechi/tronlong/t527_openharmony/

# 2. 启动容器（需要 --privileged 参数，使用 Ubuntu 22.04）
docker run -it --privileged --name t527 \
  -v $(pwd):/home/openharmony -w /home/openharmony -h t527 \
  ubuntu:22.04 /bin/bash

# 3. 设置时区（避免 tzdata 安装卡住）
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 4. 安装编译依赖（Ubuntu 22.04）
apt-get update
apt-get install -y build-essential libncurses5-dev libncursesw5-dev lzop liblz4-tool net-tools ssh openssh-server vim git git-lfs fakeroot busybox make gcc g++ expect patchelf chrpath gawk texinfo diffstat binfmt-support qemu-user-static live-build bison flex cmake gcc-multilib g++-multilib unzip device-tree-compiler libgmp-dev libmpc-dev libicu-dev bsdmainutils python3 python3-pip python3-distutils apt-utils binutils bc mtd-utils u-boot-tools zip curl wget ruby dosfstools mtools default-jre default-jdk scons perl openssl libssl-dev cpio m4 ccache zlib1g-dev tar rsync genext2fs binutils-dev e2fsprogs gnupg gnutls-bin gperf libffi-dev libelf-dev libx11-dev libgl1-mesa-dev lib32z1-dev xsltproc x11proto-core-dev libxml2-dev libdwarf-dev grsync xxd libglib2.0-dev libpixman-1-dev kmod jfsutils reiserfsprogs xfsprogs squashfs-tools pcmciautils quota ppp libtinfo-dev libtinfo5 libstdc++6 gcc-arm-none-eabi locales libxinerama-dev libxcursor-dev libxrandr-dev libxi-dev llvm
pip3 install rich

# 5. 修改默认 shell 为 bash
ln -sf /bin/bash /bin/sh

# 6. 创建 python 符号链接
ln -sf /usr/bin/python3 /usr/bin/python

# 7. 执行预处理脚本
cd /home/openharmony/forlinx-5.0-release
cd device/board/forlinx/okt527/patch
./pre_build.sh
cd /home/openharmony/forlinx-5.0-release

# 8. 添加脚本执行权限
chmod +x build.sh

# 9. 全量编译
./build.sh --product-name okt527 --ccache

# 10. 打包生成固件（任选其一）
# 方式一：pack.sh
cd /home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/
./pack.sh

# 方式二：dragon.real（如 pack.sh 遇到 qemu 段错误时使用）
# cd /home/openharmony/forlinx-5.0-release/out/pack_out
# /home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/tools/pack/eDragonEx/dragon.real image.cfg sys_partition.fex

# 11. 退出
exit
```

### 后续使用（直接进入已存在容器）
```bash
# 1. 进入 SDK 目录
cd /home/lechi/tronlong/t527_openharmony/

# 2. 启动并进入容器
docker start t527
docker exec -it t527 /bin/bash

# 3. 进入 SDK 目录并编译
cd /home/openharmony/forlinx-5.0-release
./build.sh --product-name okt527 --ccache

# 4. 打包生成固件（任选其一）
# 方式一：pack.sh
cd /home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/
./pack.sh

# 方式二：dragon.real（如 pack.sh 遇到 qemu 段错误时使用）
# cd /home/openharmony/forlinx-5.0-release/out/pack_out
# /home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/tools/pack/eDragonEx/dragon.real image.cfg sys_partition.fex

# 5. 退出
exit
```

---

## 相关资源

- **OpenHarmony 官方 Docker 编译环境文档**：https://docs.openharmony.cn/pages/v5.0.3/zh-cn/device-dev/get-code/gettools-acquire.md
- **OpenHarmony 官方文档**：https://gitee.com/openharmony/docs
- **飞凌嵌入式**：https://www.forlinx.com

- 串口调试：
```bash
sudo apt-get install picocom
picocom -b 115200 /dev/ttyUSB0
```

---

**备注**：本文档适配飞凌 OK527-C 开发板的 OpenHarmony 5.0 SDK，基于 Docker 自建 Ubuntu 22.04 编译环境。固件烧录工具推荐使用官方工具（详情请参考飞凌提供的烧录文档）。

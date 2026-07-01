# T527 OpenHarmony 5.0 Docker 编译环境完整使用文档

**注意：** 本文档为测试版本，不适用正式编译。
**适用系统**：Ubuntu 18.04 / 20.04 / 22.04
**适用平台**：全志 T527 系列开发板（飞凌 OK527-C）
**核心优势**：官方 Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言

本文专为飞凌 OK527-C 开发板的 OpenHarmony 5.0 SDK 编译打造，基于官方 Docker 镜像搭建标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

---

## 一、前期准备

### 1.1 前提条件
1. 本机系统：Ubuntu 18.04 / 20.04 / 22.04（推荐纯净系统）
2. 飞凌 T527 OpenHarmony 5.0 SDK 已解压完成，**存放路径无中文、空格、特殊字符**
3. 网络正常，可拉取 Docker 镜像

### 1.2 安装 Docker（仅执行一次）
打开终端，逐行执行以下命令，安装并配置 Docker 环境：
```bash
# 刷新软件源
sudo apt update

# 安装 Docker（Ubuntu 18.04/20.04）
sudo apt install docker.io -y

# 安装 Docker（Ubuntu 22.04 及以上）
# sudo apt install docker.io 或 sudo apt install docker-ce

# 设置 Docker 开机自启
sudo systemctl enable docker

# 启动 Docker 服务
sudo systemctl start docker

# 将当前用户加入 docker 组，后续使用免 sudo
sudo usermod -aG docker $USER
```

**关键操作**：执行完成后，**必须注销当前用户并重新登录**，否则 Docker 权限配置不生效。

### 1.3 拉取官方 Docker 镜像
```bash
# 拉取 OpenHarmony 5.0 标准版编译环境镜像
sudo docker pull swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2

# 验证镜像拉取成功
sudo docker images
```

### 1.4 SDK 目录权限修复（仅执行一次）
进入 T527 OpenHarmony SDK 根目录，修复文件权限：
```bash
# 进入 SDK 根目录（替换为你实际的 SDK 路径）
cd /media/lechi/linuxsdk/linuxsdk/openharmony_T527/

# 修复目录归属（推荐）
sudo chown -R $USER:$USER .
```

---

## 二、进入 Docker 编译环境

### 2.1 启动容器命令（首次执行）
**先进入本机 T527 OpenHarmony SDK 根目录**，再执行以下命令，自动进入编译容器：
```bash
cd /media/lechi/linuxsdk/linuxsdk/openharmony_T527/

sudo docker run -d --name okt527-oh5.0 \
-v $(pwd):/home/openharmony \
-w /home/openharmony \
swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2 \
sleep infinity
```

> **注意**：使用 `sleep infinity` 保持容器运行，方便后续进入操作。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name okt527-oh5.0` | 容器命名，区分开发板型号 |
| `-v $(pwd):/home/openharmony` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /home/openharmony` | 容器内默认进入 SDK 工作目录 |

### 2.3 重新进入已存在的容器
查看已有容器：
```bash
sudo docker ps -a
```

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
sudo docker start okt527-oh5.0
sudo docker exec -it okt527-oh5.0 /bin/bash
```

环境就绪标识：终端提示符变为
`root@xxxxx:/home/openharmony#`

---

## 三、Docker 容器内准备工作

以下命令在**Docker 容器内**执行：

### 3.1 安装必要工具
```bash
apt-get update
apt-get install -y python3-pip python3-rich
```

### 3.2 下载预编译工具链（仅首次执行）

`build.sh` 启动前依赖 `prebuilts/` 目录下的预编译工具链（gn / ninja / clang / rustc / Python / nodejs / OpenHarmony SDK 等，约 10 GB）。首次编译必须执行官方下载脚本：

```bash
cd /home/openharmony/forlinx-5.0-release
bash build/prebuilts_download.sh 2>&1 | tee prebuilts_download.log
```

> **说明**：
> - 脚本幂等，中断后重新执行可续传；
> - 成功后 `prebuilts/` 目录会生成，以后无需重复执行；
> - 若未执行，`./build.sh` 会直接报错：`[OHOS ERROR] Please execute the build/prebuilts_download.sh`。

### 3.3 执行预处理脚本
```bash
cd /home/openharmony/forlinx-5.0-release

cd device/board/forlinx/okt527/patch
./pre_build.sh

cd /home/openharmony/forlinx-5.0-release
```

---

## 四、Docker 容器内编译

### 4.1 初始化编译环境
```bash
# 进入 SDK 工作目录
cd /home/openharmony/forlinx-5.0-release

# 检查环境
ls -la build.sh
```

### 4.2 全量编译（推荐，生成完整刷机固件）
```bash
./build.sh --product-name okt527 --ccache
```


### 4.3 单独编译内核
<!--
```bash
./build.sh --product-name okt527 --ccache --build-target kernel
```
-->

### 4.4 单独编译子系统
<!--
```bash
# 编译内核
./build.sh --product-name okt527 --ccache --build-target kernel

# 编译启动引导
./build.sh --product-name okt527 --ccache --build-target bootloader

# 编译系统组件
./build.sh --product-name okt527 --ccache --build-target apps
```
-->

### 4.5 编译选项说明
| 选项 | 说明 |
|------|------|
| `--product-name` | 产品名称，飞凌 T527 使用 `okt527` |
| `--ccache` | 启用编译缓存，加速重复编译 |
| `--build-target` | 指定编译目标（kernel/bootloader/apps/acts 等） |

编译时长：30~90 分钟（取决于 CPU 核心数与内存）

### 4.3 打包生成固件
编译完成后，需要执行打包脚本生成最终的可烧录固件：
```bash
cd device/board/forlinx/okt527/kernel/build/
./pack.sh
```

**固件输出路径**：`out/pack_out/` 目录，生成的固件文件为 `okt527_uart0.img` 或类似文件。

---

## 五、退出与重新进入

### 5.1 退出容器
容器内执行 `exit`，本机 SDK 文件不受影响：
```bash
exit
```

### 5.2 下次编译流程
1. 执行以下命令重新进入已存在的容器：
   ```bash
   sudo docker start okt527-oh5.0
   sudo docker exec -it okt527-oh5.0 /bin/bash
   ```
2. 进入 SDK 目录：
   ```bash
   cd /home/openharmony/forlinx-5.0-release
   ```
3. 直接执行编译命令，**无需重复拉取镜像**：
   ```bash
   ./build.sh --product-name okt527 --ccache
   ```

---

## 六、常见问题与修复

### 6.1 Docker 拉取镜像失败
**现象**：
```
Error response from daemon: Get https://swr.cn-south-1.myhuaweicloud.com/...: dial tcp: lookup swr.cn-south-1.myhuaweicloud.com: no such host
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

### 6.2 权限问题
**现象**：
```
permission denied
```

**修复方法**（本机执行）：
```bash
cd /media/lechi/linuxsdk/linuxsdk/openharmony_T527/
sudo chown -R $USER:$USER .
```

### 6.3 编译卡住或内存不足
**现象**：编译过程中系统变卡或崩溃

**修复方法**：

1、修改 `kernel/linux/common_modules/memory_security/Makefile` 文件，在 `ccflags-*` 中新增 `-I$(obj)` 编译参数：

```makefile
ccflags-$(CONFIG_HIDE_MEM_ADDRESS) += \
    -I$(obj) \
    -I$(srctree)/fs/proc \
    -I$(srctree)/fs/proc/memory_security/include \
    -I$(srctree)/security/selinux/include \
    -I$(srctree)/security/selinux

ccflags-$(CONFIG_JIT_MEM_CONTROL) += \
    -I$(obj) \
    -I$(srctree)/fs/proc \
    -I$(srctree)/fs/proc/memory_security/include \
    -I$(srctree)/security/selinux/include \
    -I$(srctree)/security/selinux
```

2、修改 `device/board/forlinx/okt527/kernel/build/scripts/mkkernel.sh` 文件。
找到以下代码行：
```bash
MAKE+=" ARCH=${ARCH} -j${LICHEE_JLEVEL} O=${BUILD_OUT_DIR}"
```
将其修改为：
```bash
#MAKE+=" ARCH=${ARCH} -j${LICHEE_JLEVEL} O=${BUILD_OUT_DIR}"
MAKE+=" ARCH=${ARCH} -j8 O=${BUILD_OUT_DIR}"
```


### 6.4 编译报错处理
**现象**：编译过程中出现 `FileNotFoundError: error.log` 等错误

**修复方法**：这是 hb 工具的 bug，不影响实际编译结果，可忽略。检查 out 目录下是否有生成的产物。

### 6.5 GPIO 驱动编译错误
**现象**：`gpio_adapter.c` 中 `gpiod_get_direction` 和 `gpio_to_desc` 隐式声明错误

**原因**：内核源码编译时会重新克隆到 `out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/`，原始源码修改需同步

**修复方法**：
1. 修改 `drivers/hdf_core/adapter/khdf/linux/platform/gpio/gpio_adapter.c`
   添加头文件：
   ```c
   #include <linux/gpio.h>
   #include <linux/gpio/consumer.h>
   #include <linux/gpio/driver.h>
   #include <linux/interrupt.h>
   ```

   注释掉 `gpiochip_find` 调用：
   ```c
   #if 0
       (void)gpiochip_find(device, LinuxGpioMatchProbe);
   #endif
   ```

2. 复制修复后的文件到内核编译目录：
   ```bash
   cp drivers/hdf_core/adapter/khdf/linux/platform/gpio/gpio_adapter.c \
      out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/drivers/hdf/khdf/platform/gpio/
   ```

### 6.6 rtc_time64_to_tm 未定义引用
**现象**：内核链接时 `blackbox_common.o` 报 `rtc_time64_to_tm` 未定义引用

**修复方法**：
1. 修改 `kernel/linux/linux-5.10/drivers/staging/blackbox/blackbox_common.c`
   在文件开头添加：
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

2. 复制修复后的文件到内核编译目录：
   ```bash
   cp kernel/linux/linux-5.10/drivers/staging/blackbox/blackbox_common.c \
      out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/drivers/staging/blackbox/
   ```

3. 提交到本地 git 仓库：
   ```bash
   cd kernel/linux/linux-5.10
   git add drivers/staging/blackbox/blackbox_common.c
   git commit -m "Add rtc_time64_to_tm stub for blackbox"
   ```

### 6.7 编译产物清理
```bash
# 清理编译产物（保留源码）
rm -rf out/

# 清理编译缓存
rm -rf ~/.cache/build
```

### 6.8 内核 git 提交说明
编译过程中对内核源码的修改需要提交到本地 git 仓库，否则编译时克隆的源码不包含修改：
```bash
cd /home/openharmony/forlinx-5.0-release/kernel/linux/linux-5.10
git config user.email "your@email.com"
git config user.name "Your Name"
git add <modified-files>
git commit -m "Fix description"
```

---

### 6.9 打包失败问题

#### 6.9.1 busybox 未安装
执行打包命令./pack.sh有提示 busybox: command not found

**修复方法**：安装 busybox
```bash
docker exec okt527-oh5.0 apt-get update && docker exec okt527-oh5.0 apt-get install -y busybox
```




## 十、编译结果验证

### 10.1 验证编译成功
编译成功标识：
```
[OHOS INFO] okt527 build success
[OHOS INFO] Cost Time:  HH:MM:SS
=====build  successful=====
```

### 10.2 固件输出路径
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

### 10.3 固件打包
如果编译成功但未自动打包，执行：
```bash
cd /home/openharmony/forlinx-5.0-release/device/board/forlinx/okt527/kernel/build/
./pack.sh
```

---

## 七、容器时区设置（可选）

如需将容器时区设置为北京时间（Asia/Shanghai），在容器内执行：
```bash
# 安装时区数据（如未安装）
apt-get update && apt-get install -y tzdata

# 设置时区为上海
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 验证
date
```
---

## 九、注意事项

1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
3. 如需彻底删除容器重建环境，执行：
   ```bash
   sudo docker stop okt527-oh5.0 && sudo docker rm okt527-oh5.0
   ```
4. 首次拉取镜像耗时较长，请耐心等待
5. 每次进入容器后，必须先进入 SDK 目录 `cd /home/openharmony`

---

## 快捷操作总结（一键记忆）

### 首次使用（创建容器并进入）
```bash
# 1. 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/openharmony_T527/

# 2. 拉取官方 Docker 镜像（如未拉取）
sudo docker pull swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2

# 3. 启动容器（首次创建，使用 sleep infinity 保持运行）
sudo docker run -d --name okt527-oh5.0 \
-v $(pwd):/home/openharmony \
-w /home/openharmony \
swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2 \
sleep infinity

# 4. 进入容器
sudo docker exec -it okt527-oh5.0 /bin/bash

# 5. 安装必要的工具（首次进入容器）
apt-get update
apt-get install -y python3-pip

# 6. 执行预处理脚本
cd /home/openharmony/forlinx-5.0-release
cd device/board/forlinx/okt527/patch
./pre_build.sh
cd /home/openharmony/forlinx-5.0-release
bash build/prebuilts_download.sh
# 7. 全量编译（同时输出到终端和日志文件 build.log）
./build.sh --product-name okt527 --ccache 2>&1 | tee build.log

# 8. 打包生成固件（如未自动打包）
cd device/board/forlinx/okt527/kernel/build/
./pack.sh

# 9. 退出
exit
```

### 后续使用（直接进入已存在容器）
```bash
# 1. 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/openharmony_T527/

# 2. 启动已存在的容器
sudo docker start okt527-oh5.0

# 3. 进入容器
sudo docker exec -it okt527-oh5.0 /bin/bash

# 4. 进入 SDK 目录并编译（首次可能需补跑 prebuilts_download）
cd /home/openharmony/forlinx-5.0-release
# 若还未执行过，首次进容器请先跑：
# bash build/prebuilts_download.sh 2>&1 | tee prebuilts_download.log
./build.sh --product-name okt527 --ccache 2>&1 | tee build.log

# 5. 打包生成固件
cd device/board/forlinx/okt527/kernel/build/
./pack.sh

# 6. 退出
exit
```

---

## 相关资源

- **OpenHarmony 官方 Docker 编译环境文档**：https://docs.openharmony.cn/pages/v5.0.3/zh-cn/device-dev/get-code/gettools-acquire.md
- **OpenHarmony 官方文档**：https://gitee.com/openharmony/docs
- **飞凌嵌入式**：https://www.forlinx.com
- **Docker 镜像仓库**：swr.cn-south-1.myhuaweicloud.com/openharmony-docker/

- 串口调试
-sudo apt-get install picocom

- 使用：
-picocom -b 115200 /dev/ttyUSB0
---

**备注**：本文档适配飞凌 OK527-C 开发板的 OpenHarmony 5.0 SDK，Docker 编译环境基于官方标准镜像，与官方编译要求一致。
固件烧录工具推荐使用官方工具（详情请参考飞凌提供的烧录文档）。

---

## 附录：关键文件路径
以下是飞凌 T527 开发板的关键配置文件路径：

| 类型 | 路径 |
|------|------|
| 设备树（Bootloader） | `device/board/forlinx/okt527/bootloader/configs/okt527/linux-5.10/board.dts` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/openharmony_T527/forlinx-5.0-release/device/board/forlinx/okt527/bootloader/configs/okt527/linux-5.10/board.dts |
| 设备树（DTSI） | `device/board/forlinx/okt527/bootloader/configs/default/linux-5.10/sun55iw3p1.dtsi` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/openharmony_T527/forlinx-5.0-release/device/board/forlinx/okt527/bootloader/configs/default/linux-5.10/sun55iw3p1.dtsi |
| 编译配置 | `device/soc/allwinner/t527/patches/config/t527_standard_defconfig` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/openharmony_T527/forlinx-5.0-release/device/soc/allwinner/t527/patches/config/t527_standard_defconfig |
| init 启动配置 | `base/startup/init/services/etc/init.cfg` |
|  | 路径：file:///media/lechi/linuxsdk/linuxsdk/openharmony_T527/forlinx-5.0-release/base/startup/init/services/etc/init.cfg |

# T113i SDK Docker 编译环境完整使用文档
**适用系统**：Ubuntu 18.04
**适用平台**：全志 T113i 系列开发板（创龙）
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言
本文专为全志 T113i SDK（Tina Linux）编译打造，基于 Docker 搭建 Ubuntu 18.04 标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

---

## 一、前期准备
### 1.1 前提条件
1. 本机系统：Ubuntu 18.04（推荐纯净系统，无冗余软件源冲突）
2. T113i 完整 SDK 已解压完成，**存放路径无中文、空格、特殊字符**
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
进入 T113i SDK 根目录，修复文件权限，避免编译时报读写权限错误：
```bash
# 进入 SDK 根目录（替换为你实际的 SDK 路径）
cd /media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5
# 修复目录归属（推荐）
sudo chown -R $USER:$USER .
# 备用命令（上一条命令报错时使用）
# sudo chmod -R 777 .
```

---

## 二、进入 Docker 编译环境
### 2.1 启动容器命令（首次执行）
**先进入本机 T113i SDK 根目录**，再执行以下命令，自动进入编译容器：
```bash
docker run -it \
--name t113i-sdk \
-v $(pwd):/workspace \
-w /workspace \
-h t113i-build \
ubuntu:18.04 \
/bin/bash
```

> **注意**：此处已移除 `--rm` 参数，用于保留容器环境，避免每次重复安装依赖。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name t113i-sdk` | 容器命名，区分开发板型号 |
| `-v $(pwd):/workspace` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /workspace` | 容器内默认进入 SDK 工作目录 |
| `-h t113i-build` | 设置容器主机名，方便识别 |

### 2.3 重新进入已存在的容器
查看已有容器：
```bash
sudo docker ps -a
```

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
docker start t113i-sdk
docker exec -it t113i-sdk /bin/bash
```

环境就绪标识：终端提示符变为
`root@t113i-build:/workspace#`

---

## 三、安装编译依赖（仅首次进入容器安装）
在 Docker 容器内执行以下命令，一键安装 T113i SDK 全部编译依赖：
```bash
apt update && apt-get install -y \
git ssh make gcc libssl-dev \
liblz4-tool expect g++ patchelf chrpath gawk texinfo \
diffstat binfmt-support qemu-user-static live-build bison flex fakeroot libfakeroot \
cmake gcc-multilib g++-multilib unzip device-tree-compiler \
libncurses5-dev zlib1g-dev libglib2.0-dev gettext libelf-dev \
bzip2 expat gpgv2 bc python3 python3-pip \
pkg-config rsync bsdmainutils wget curl cpio swig \
libpython3-dev libpython3.7 libpython3.7-dev libffi-dev \
xxd vim-common busybox
```

依赖安装完成后，执行以下初始化配置（**每次重建容器后执行一次**）：
```bash
# 创建 python 软链接（Ubuntu 18.04 默认无 python 命令）
ln -sf /usr/bin/python3 /usr/bin/python

# 验证
python --version
gcc --version
git --version
```

---

## 四、SDK 编译指令
在 Docker 容器内，执行以下命令初始化编译环境：

### 4.1 初始化编译环境
```bash
# 进入 SDK 工作目录
cd /workspace/tina5.0_v1.0
# 加载编译环境
source build/envsetup.sh
```

### 4.2 选择编译目标方案
```bash
# 交互式选择方案
./build.sh config
```
根据提示选择对应的方案，例如 `t113_i tlt113-evm-emmc`。

### 4.3 全量编译（推荐，生成完整刷机固件）
```bash
./build.sh
```

### 4.4 打包固件
```bash
./build.sh pack
```
打包成功后固件位于：`out/t113_i/tlt113-evm-emmc/pack_out/` 目录下。

### 4.5 其他常用编译命令
```bash
# SPL 和 U-Boot 编译
./build.sh bootloader

# 内核编译
./build.sh kernel

# 文件系统编译
./build.sh buildroot_rootfs

# 配置内核选项
./build.sh menuconfig

# 配置 buildroot
./build.sh buildroot_menuconfig
```

编译时长：15~40 分钟（取决于 CPU 核心数与内存）
**固件输出路径**：`out/t113_i/<方案名>/pack_out/` 目录

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
   docker start t113i-sdk
   docker exec -it t113i-sdk /bin/bash
   ```
2. 进入 SDK 目录并加载编译环境：
   ```bash
   cd /workspace/tina5.0_v1.0
   source build/envsetup.sh
   ```
3. 直接执行编译命令，**无需重复安装依赖**：
   ```bash
   ./build.sh
   ./build.sh pack
   ```

---

## 六、常见问题与修复

### 6.1 U-Boot（brandy）编译问题

#### 问题1：xxd 命令找不到
**现象**：编译 bootloader 时报错：
```
/bin/bash: xxd: command not found
make: *** [board/sunxi/sunxi_challenge.c] Error 127
ERROR: build brandy Failed
```

**修复方法**：安装 vim-common（包含 xxd）：
```bash
apt-get install -y xxd vim-common
```

### 6.2 内核编译问题

#### 问题2：缺少 python 命令
**现象**：编译过程中报错：
```
/usr/bin/env: 'python': No such file or directory
ERROR: build kernel Failed
```

**原因**：Ubuntu 18.04 容器中只有 `python3`，没有 `python` 命令。

**修复方法**：创建软链接（容器内执行一次即可）：
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

#### 问题3：缺少 libncurses 库
**现象**：执行 `./build.sh menuconfig` 报错：
```
*** Unable to find the ncurses libraries
```

**修复方法**：安装缺失库：
```bash
apt-get install -y libncurses5-dev libncursesw5-dev
```

### 6.3 buildroot 文件系统编译问题

#### 问题4：libpython3.7 共享库缺失
**现象**：编译 buildroot 时报错：
```
libpython3.7m.so.1.0: cannot open shared object file: No such file or directory
ERROR: build buildroot Failed
```

**修复方法**：安装 Python 3.7 开发库：
```bash
apt-get install -y libpython3.7 libpython3.7-dev
```

#### 问题5：libfakeroot.so 找不到
**现象**：编译 buildroot rootfs 时报错：
```
fakeroot: preload library `libfakeroot.so' not found, aborting.
ERROR: build buildroot Failed
```

**原因**：buildroot 自己编译的 fakeroot 运行时找不到 libfakeroot.so 共享库。

**修复方法**：在容器内安装宿主机 fakeroot 库：
```bash
apt-get install -y fakeroot libfakeroot
```

如果任然编译失败，用宿主机 fakeroot 替换 buildroot 编译的版本
# 查找 buildroot 的 fakeroot 路径
ls /workspace/tina5.0_v2.5/tina5.0_v1.0/out/t113_i/tlt113-evm-emmc/buildroot/buildroot/host/bin/fakeroot

# 用宿主机 fakeroot 替换
cp $(which fakeroot) /workspace/tina5.0_v2.5/tina5.0_v1.0/out/t113_i/tlt113-evm-emmc/buildroot/buildroot/host/bin/fakeroot

# 同时复制 libfakeroot.so
find /usr -name "libfakeroot*.so*" 2>/dev/null

安装后重新编译：
```bash
./build.sh buildroot_rootfs
```

### 6.4 固件打包问题

#### 问题6：busybox 工具不存在
**现象**：执行 `./build.sh pack` 时报错：
```
ERROR: Tool busybox does not exist!
```

**修复方法**：安装 busybox：
```bash
apt-get install -y busybox
```

### 6.5 基础编译工具缺失

#### 问题7：gcc / git 找不到
**现象**：编译时报错：
```
/bin/sh: 1: cc: not found
/bin/bash: git: command not found
```

**原因**：容器内未安装基础编译依赖。

**修复方法**：执行第三章完整依赖安装命令。

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
3. 如需彻底删除容器重建环境，执行：
   ```bash
   docker stop t113i-sdk && docker rm t113i-sdk
   ```
4. 出现 `Permission denied` 权限报错，回到本机执行 1.3 节权限修复命令
5. Docker 安装后必须注销重登，否则无法正常使用容器
6. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
7. 每次进入容器后，必须先进入 SDK 目录并执行 `source build/envsetup.sh`

---

## 快捷操作总结（一键记忆）

### 首次使用（创建容器并安装依赖）
```bash
# 1. 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5

# 2. 启动 Docker 容器（首次创建）
docker run -it --name t113i-sdk -v $(pwd):/workspace -w /workspace -h t113i-build ubuntu:18.04 /bin/bash

# 若拉取镜像失败，换源后重试
sudo tee /etc/docker/daemon.json <<EOF
{
"registry-mirrors": ["https://ccr.ccs.tencentyun.com/"]
}
EOF
sudo systemctl daemon-reload && sudo systemctl restart docker

# 3. 在容器内安装全部依赖（预设时区，避免 tzdata 卡死交互）
export DEBIAN_FRONTEND=noninteractive
export TZ=Asia/Shanghai
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
apt update && apt-get install -y -o Dpkg::Options::="--force-confnew" tzdata
apt-get install -y git ssh make gcc libssl-dev liblz4-tool expect g++ patchelf chrpath gawk texinfo diffstat binfmt-support qemu-user-static live-build bison flex fakeroot libfakeroot cmake gcc-multilib g++-multilib unzip device-tree-compiler libncurses5-dev zlib1g-dev libglib2.0-dev gettext libelf-dev bzip2 expat gpgv2 bc python3 python3-pip pkg-config rsync bsdmainutils wget curl cpio swig libpython3-dev libpython3.7 libpython3.7-dev libffi-dev xxd vim-common busybox

# 4. 创建 python 软链接
ln -sf /usr/bin/python3 /usr/bin/python

# 5. 进入 SDK 工作目录并加载编译环境
cd /workspace/tina5.0_v1.0
source build/envsetup.sh

# 6. 选择编译方案
./build.sh config

# 7. 全量编译
./build.sh

# 8. 打包固件
./build.sh pack

# 9. 退出
exit
```

### 后续使用（直接进入已存在容器）
```bash
# 1. 启动已存在的容器
docker start t113i-sdk
# 2. 进入容器
docker exec -it t113i-sdk /bin/bash
# 3. 进入 SDK 工作目录并加载编译环境
cd /workspace/tina5.0_v1.0
source build/envsetup.sh
# 4. 直接编译（无需重复安装依赖）
./build.sh
# 5. 打包固件
./build.sh pack
# 6. 退出
exit
```

---
**备注**：本文档适配全志 T113i Tina Linux SDK，Docker 编译环境基于 Ubuntu 18.04，与官方编译要求一致。
固件烧录工具推荐使用全志官方 PhoenixSuit（Windows）或 sunxi-fel（Linux）。

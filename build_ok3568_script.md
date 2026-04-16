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
cd /home/lechi/tronlong/RK3568_sdk/
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
cd /home/lechi/tronlong/RK3568_sdk/

docker run -it \
--name RK3568_sdk \
-v $(pwd):/workspace \
-w /workspace \
-h rk3568-build \
ubuntu:20.04 \
/bin/bash
```

> **注意**：此处已移除 `--rm` 参数，用于保留容器环境，避免每次重复安装依赖。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name RK3568_sdk` | 容器命名，区分开发板型号 |
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
docker start RK3568_sdk
docker exec -it RK3568_sdk /bin/bash
```

环境就绪标识：终端提示符变为
`root@rk3568-build:/workspace#`

---

## 三、安装编译依赖（仅首次进入容器安装）
在 Docker 容器内执行以下命令，一键安装 RK3568 Buildroot SDK 全部编译依赖：
```bash
apt update && apt-get install -y \
git ssh make gcc libssl-dev \
liblz4-tool expect expect-dev g++ patchelf chrpath gawk texinfo chrpath \
diffstat binfmt-support qemu-user-static live-build bison flex fakeroot \
cmake gcc-multilib g++-multilib unzip device-tree-compiler ncurses-dev \
libgucharmap-2-90-dev bzip2 expat gpgv2 cpp-aarch64-linux-gnu libgmp-dev \
libmpc-dev bc python-is-python3 python2 libpkgconf-dev rsync bsdmainutils \
uuid-runtime swig build-essential libncurses-dev python3-distutils
```

> **说明**：
> - `rsync` 和 `bsdmainutils`（包含 hexdump）是打包固件镜像时的必需依赖
> - `uuid-runtime` 和 `swig` 是 Buildroot 配置工具的依赖
> - `build-essential` 和 `libncurses-dev` 是交叉编译工具链的依赖

依赖安装完成后，给编译脚本添加执行权限：
```bash
chmod +x ubuntu/build.sh
chmod +x build.sh
```

---

## 四、SDK 编译指令
在 Docker 容器内，直接执行编译命令，根据需求选择：

### 4.1 全量编译（推荐，生成完整刷机固件）
```bash
./build.sh
```
或者使用 Makefile 方式：
```bash
make
```

### 4.2 编译 Buildroot
```bash
# 进入 Buildroot 目录
cd buildroot

# 配置 Buildroot（可选）
make menuconfig

# 编译 Buildroot
make
```

### 4.3 单独编译各模块
```bash
# 仅编译 U-Boot
./build.sh uboot
# 编译完成后将在 rockdev/ 目录生成 u-boot 相关镜像

# 仅编译内核
./build.sh kernel
# 编译完成后将生成内核镜像文件 boot.img 或 boot.tar

# 仅编译根文件系统
./build.sh rootfs
# 编译完成后将生成 rootfs.squashfs 或 rootfs.tar
```

### 4.4 打包完整固件
```bash
./build.sh all
# 或
make release
```

编译时长：20~60 分钟（取决于 CPU 核心数与内存）
**固件输出路径**：SDK 根目录 `rockdev/` 或 `output/` 文件夹

---

## 五、Buildroot 配置说明
### 5.1 进入配置菜单
```bash
cd buildroot
make menuconfig
```

### 5.2 常用配置项
| 配置项 | 说明 |
|--------|------|
| Target options | 目标架构选择（AARCH64） |
| Build options | 编译选项（并行编译数等） |
| Toolchain | 交叉编译工具链配置 |
| System configuration | 系统配置（主机名、root 密码等） |
| Kernel | 内核配置 |
| Target packages | 目标软件包选择 |

---

## 六、退出与重新进入
### 6.1 退出容器
容器内执行 `exit`，本机 SDK 文件不受影响：
```bash
exit
```

### 6.2 下次编译流程
1. 进入本机 SDK 根目录
   ```bash
   cd /home/lechi/tronlong/RK3568_sdk/
   ```
2. 执行以下命令重新进入已存在的容器：
   ```bash
   docker start RK3568_sdk
   docker exec -it RK3568_sdk /bin/bash
   ```
3. 直接执行编译命令，**无需重复安装依赖**

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
  "registry-mirrors": [
    "https://ccr.ccs.tencentyun.com/",
    "https://docker.mirrors.ustc.edu.cn/",
    "https://hub-mirror.c.163.com/"
  ]
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
cd /home/lechi/tronlong/RK3568_sdk/
sudo chown -R $USER:$USER .
```

### 7.3 编译卡住或内存不足
**现象**：编译过程中系统变卡或崩溃

**修复方法**：
```bash
# 限制 Docker 容器内存使用（根据机器配置调整）
docker run -it --memory=8g ...
```

### 7.4 编译产物清理
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

## 八、注意事项
1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
3. 如需彻底删除容器重建环境，执行：
   ```bash
   docker stop RK3568_sdk && docker rm RK3568_sdk
   ```
4. 首次进入容器需要安装依赖，耗时较长，请耐心等待
5. Buildroot 编译会下载大量源码包，请确保网络稳定

---

## 快捷操作总结（一键记忆）
### 首次使用（创建容器并进入）
```bash
# 1. 进入 SDK 目录
cd /home/lechi/tronlong/RK3568_sdk/

# 2. 启动容器（首次创建）
docker run -it --name RK3568_sdk -v $(pwd):/workspace -w /workspace -h rk3568-build ubuntu:20.04 /bin/bash

# 3. 在容器内安装编译依赖
apt update && apt-get install -y git ssh make gcc libssl-dev liblz4-tool expect expect-dev g++ patchelf chrpath gawk texinfo diffstat binfmt-support qemu-user-static live-build bison flex fakeroot cmake gcc-multilib g++-multilib unzip device-tree-compiler ncurses-dev bzip2 expat libgmp-dev libmpc-dev bc python-is-python3 python2 rsync bsdmainutils uuid-runtime swig build-essential libncurses-dev

# 4. 添加脚本执行权限
chmod +x build.sh

# 5. 执行编译
./build.sh
```

### 下次使用（重新进入容器并编译）
```bash
cd /home/lechi/tronlong/RK3568_sdk/
docker start RK3568_sdk
docker exec -it RK3568_sdk /bin/bash
cd /workspace
./build.sh
```

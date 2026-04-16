# RK3562 SDK Docker 编译环境完整使用文档
**适用系统**：Ubuntu 20.04.6
**适用平台**：瑞芯微 RK3562 系列开发板
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
cd /home/ubuntu/tronlong/rk3562_sdk
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
**固件输出路径**：SDK 根目录 `rockdev/` 或 `output/` 文件夹

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

## 快捷操作总结（一键记忆）

### 首次使用（创建容器并安装依赖）
```bash
# 1. 进入 SDK 目录
cd /home/ubuntu/tronlong/rk3562_sdk
# 2. 启动 Docker 容器（首次创建）
docker run -it --name rk3562-sdk -v $(pwd):/workspace -w /workspace -h rk3562-build ubuntu:20.04 /bin/bash

#失败，换源
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
./ubuntu/build.sh all
# 6. 退出
exit
```

### 后续使用（直接进入已存在容器）
```bash
# 1. 启动已存在的容器
docker start rk3562-sdk
# 2. 进入容器
docker exec -it rk3562-sdk /bin/bash
# 3. 直接编译（无需重复安装依赖）
cd ubuntu
./build.sh all
# 的 MiniLoaderAll.bin、uboot.img、boot.img、rootfs.img 镜像存放至"output/Image/"目录下，替换原有的同名文件 合成新镜像update.img

# 替换完成后，执行./mkimage.sh pack，即可在"output/update"目录合成新的 update.img 镜像
# 4. 退出
exit
```

---
**备注**：本文档适配官方 RK3562 Ubuntu SDK，Docker 环境与官方编译要求完全一致。
应用编译工具链 /home/tronlong/RK3562/Ubuntu/rk3562-ubuntu20.04-sdk-v1.0/environment

uboot和kernel编译工具链 export PATH=/home/tronlong/RK3562/ubuntu/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
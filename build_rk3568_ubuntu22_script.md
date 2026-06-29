# RK3568 Forlinx Desktop 22.04 Docker 编译环境使用文档
**适用系统**：Ubuntu 22.04（Docker 容器）
**适用平台**：瑞芯微 RK3568 系列开发板（飞凌 OK3568-C）
**官方参考**：原厂文档/rk3568_ubuntu.md
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突，编译环境稳定纯净。

## 前言
Forlinx Desktop 系统是飞凌在 Ubuntu base 基础上构建的桌面操作系统，完全兼容 Ubuntu 22.04，支持 apt-get 等，相对传统 Linux 系统易用性更高。
本文基于 Docker 搭建 Ubuntu 22.04 编译环境，完全适配官方编译要求。

## 环境信息
| 项目 | 版本 |
|------|------|
| 开发环境 | Ubuntu 22.04 64位 |
| 交叉工具链 | aarch64-linux-gnu |
| Bootloader | u-boot-2017.09 |
| 内核版本 | linux-5.10.160 |
| QT 版本 | qt5.15.3 |
| 编译内存要求 | 8GB 及以上 |

---

## 一、前期准备
### 1.1 前提条件
- 本机系统：Ubuntu 20.04/22.04
- RK3568 SDK 已解压完成，路径无中文、空格、特殊字符
- 网络正常

### 1.2 安装 Docker（仅执行一次）
```bash
sudo apt update
sudo apt install docker.io -y
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```
**必须注销重新登录**使 docker 组生效。

### 1.3 SDK 目录权限修复
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu
sudo chown -R $USER:$USER .
```

### 1.4 源码解压
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu
cat OK3568-linux-source.tar.bz2.0* > OK3568-linux-source.tar.bz2
tar -xvf OK3568-linux-source.tar.bz2
```

---

## 二、进入 Docker 编译环境
### 2.1 首次启动容器
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu

docker run -it --privileged \
--name rk3568_ubuntu \
-v $(pwd):/workspace \
-w /workspace \
-h rk3568-ubuntu \
ubuntu:22.04 \
/bin/bash
```
`--privileged` 必须添加，否则挂载镜像报错 `Operation not permitted`。

### 2.2 再次进入容器
```bash
docker start rk3568_ubuntu
docker exec -it rk3568_ubuntu /bin/bash
```
环境就绪：`root@rk3568-ubuntu:/workspace#`

---

## 三、安装编译依赖（仅首次执行）
```bash
# 时区设置
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 安装依赖
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y \
build-essential libncurses* lzop net-tools \
openssh-server vim git fakeroot ssh make gcc libssl-dev liblz4-tool \
expect g++ patchelf chrpath gawk texinfo diffstat binfmt-support \
qemu-user-static live-build bison flex cmake gcc-multilib g++-multilib \
unzip device-tree-compiler python3-pip python2 libgmp-dev libmpc-dev \
libicu-dev bsdmainutils bc sudo time uuid-runtime rsync

# python 符号链接
ln -sf /usr/bin/python3 /usr/bin/python

# 脚本权限
chmod +x /workspace/OK3568-linux-source/build.sh
```

---

## 四、编译流程（参考原厂文档）

### 4.1 选择编译配置
初次解压内核源码后，需先选择编译配置：
```bash
cd /workspace/OK3568-linux-source
./build.sh defconfig
```
执行后弹出选择界面，输入 `3` 按回车。

### 4.2 全编译
完成配置后执行全编译：
```bash
cd /workspace/OK3568-linux-source
./build.sh
```
编译时长 20~60 分钟，编译成功后在 `rockdev/` 目录生成镜像文件。
`update.img` 为打包好用于 OTG 或 TF 卡完全烧写用，其它文件为分步烧写使用。

### 4.3 单独编译内核
```bash
cd /workspace/OK3568-linux-source
./build.sh kernel
```
编译成功后 update.img 里的内核不更新，需分步烧写 `kernel/boot.img`。

###4.4 清除编译生成的文件
用户在内核源码路径下进行操作。

./build.sh cleanall

该操作清除所有中间文件。但不影响源文件，包括已经有改动的源文件。

### 4.4 后台编译（避免终端断连）
```bash
docker exec -d rk3568_ubuntu bash -c "cd /workspace/OK3568-linux-source && ./build.sh 2>&1 | tee build.log"
docker exec rk3568_ubuntu tail -f /workspace/OK3568-linux-source/build.log
```

---

## 五、清除编译产物
```bash
cd /workspace/OK3568-linux-source
./build.sh cleanall
```
该操作清除所有中间文件，但不影响源文件（包括已有改动的源文件）。

---

## 六、Image 文件使用
`update.img` 为打包好用于 OTG 或 TF 卡完全烧写用，其它文件为分步烧写使用。
单独编译生成的 Image 文件不会在 `update.img` 中更新，需使用单步烧写来烧录（详见软件手册 OTG 烧写）。

---

## 七、退出与重新进入
### 退出容器
```bash
exit
```
### 下次编译
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu
docker start rk3568_ubuntu
docker exec -it rk3568_ubuntu /bin/bash
cd /workspace/OK3568-linux-source
./build.sh
```

---

## 八、常见问题
### Docker 镜像拉取失败
```bash
sudo tee /etc/docker/daemon.json <<EOF
{"registry-mirrors": ["https://ccr.ccs.tencentyun.com/"]}
EOF
sudo systemctl daemon-reload && sudo systemctl restart docker
```

### 权限问题
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu
sudo chown -R $USER:$USER .
```

### kconf GLIBC 版本不匹配
```bash
cd /workspace/OK3568-linux-source/buildroot/support/kconfig
make -f Makefile.br HOSTCC=gcc conf
cp conf /workspace/OK3568-linux-source/output/kconf/conf
```

### python: command not found
```bash
ln -sf /usr/bin/python3 /usr/bin/python
```

### 编译内存不足
```bash
docker run -it --memory=8g ...
```

---

## 九、注意事项
1. SDK 路径严禁中文、空格、特殊字符
2. 初次解压源码后必须先全编译，再根据需要单独编译
3. 编译需要 8GB 以上内存
4. 编译过程不要中断
5. 容器名 `rk3568_ubuntu` 与 `rk3568_sdk` 独立，可同时存在

---

## 快捷操作总结

### 首次使用
```bash
# 1. 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu

# 2. 启动容器（Ubuntu 22.04）
docker run -it --privileged --name rk3568_ubuntu \
  -v $(pwd):/workspace -w /workspace -h rk3568-ubuntu \
  ubuntu:22.04 /bin/bash

# 3. 安装依赖
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y build-essential libncurses* lzop net-tools \
  openssh-server vim git fakeroot ssh make gcc libssl-dev liblz4-tool \
  expect g++ patchelf chrpath gawk texinfo diffstat binfmt-support \
  qemu-user-static live-build bison flex cmake gcc-multilib g++-multilib \
  unzip device-tree-compiler python3-pip python2 libgmp-dev libmpc-dev \
  libicu-dev bsdmainutils bc sudo time uuid-runtime rsync

# 4. python 符号链接 + 脚本权限
ln -sf /usr/bin/python3 /usr/bin/python
chmod +x /workspace/OK3568-linux-source/build.sh

# 5. 选择配置 + 全编译
cd /workspace/OK3568-linux-source
./build.sh defconfig   # 选择 3
./build.sh
# 输出: rockdev/update.img
```

### 下次编译
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu
docker start rk3568_ubuntu
docker exec -it rk3568_ubuntu /bin/bash
cd /workspace/OK3568-linux-source
./build.sh
```

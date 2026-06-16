# RK3562 SDK Docker 启动命令

## 概述

本文档记录 Tronlong RK3562 SDK 的 Docker 环境启动命令。

## 快速启动

### 1. 启动 RK3562 Docker 环境

docker run -it --rm \
--name rk3562-sdk \
-v $(pwd):/workspace \
-w /workspace \
-h rk3562-build \
ubuntu:20.04 \
/bin/bash

 ./init.sh

U-boot

cd  /workspace/ubuntu/U-boot
配置交叉编译工具链环境变量并清理内核
export PATH=$PATH:/workspace/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH



make distclean

make rk3562_defconfig

cd /workspace/ubuntu/U-boot
./make.sh CROSS_COMPILE=aarch64-none-linux-gnu- rk3562 --spl-new

编译完成后将生成U-Boot镜像、rk3562_spl_loader_v1.05.106.bin镜像、idblock.img 镜像

Kernel

cd  /workspace/ubuntu/Kernel
配置交叉编译工具链环境变量并清理内核
export PATH=$PATH:/workspace/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH

make CROSS_COMPILE=aarch64-none-linux-gnu- ARCH=arm64 distclean

make -j8 CROSS_COMPILE=aarch64-none-linux-gnu- ARCH=arm64 rockchip_linux_defconfig

修改内核编译选项配置，可继续执行如下命令打开图形配置界面。如无需修改内核编译选项配置，可跳过此步骤。
make -j8 CROSS_COMPILE=aarch64-none-linux-gnu- ARCH=arm64 menuconfig

make -j8 CROSS_COMPILE=aarch64-none-linux-gnu- ARCH=arm64 savedefconfig

mv defconfig arch/arm64/configs/rockchip_linux_defconfig

编译内核镜像

make -j8 CROSS_COMPILE=aarch64-none-linux-gnu- ARCH=arm64 tl3562-evm.img


编译完成后，将生成内核镜像文件boot.img。




## 参数说明

| 参数 | 说明 |
|------|------|
| `-it` | 交互式终端模式 |
| `--rm` | 容器停止后自动删除 |
| `--privileged` | 赋予容器特权模式（用于访问USB设备等） |
| `-v` | 挂载主机目录到容器 |
| `-w` | 设置容器内工作目录 |
| `-d` | 后台运行模式 |
| `--name` | 指定容器名称 |

## 注意事项

1. 确保 Docker 服务已启动：`sudo systemctl start docker`
2. 首次运行可能需要拉取镜像，请确保网络连接正常
3. 使用 `--privileged` 模式时注意安全性
4. 编译时建议使用多核并行编译以加快速度

## 参考

- Tronlong 官方文档
- RK3562 SDK 用户手册

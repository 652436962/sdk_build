#!/bin/bash

# RK3562 SDK 编译脚本
# 使用方法: ./build.sh [uboot|kernel|all]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息函数
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 脚本所在目录（全局变量，供所有函数使用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置交叉编译工具链
setup_toolchain() {
    info "设置交叉编译工具链..."
    
    # 工具链路径（相对于本脚本所在目录）
    TOOLCHAIN_PATH="${SCRIPT_DIR}/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin"
    
    if [ ! -d "$TOOLCHAIN_PATH" ]; then
        error "工具链路径不存在: $TOOLCHAIN_PATH"
        exit 1
    fi
    
    export PATH="${TOOLCHAIN_PATH}:$PATH"
    export CROSS_COMPILE=aarch64-none-linux-gnu-
    export ARCH=arm64
    
    info "工具链设置完成"
    info "CROSS_COMPILE: $CROSS_COMPILE"
    info "ARCH: $ARCH"
}

# 清理 U-Boot
clean_uboot() {
    info "===================="
    info "清理 U-Boot..."
    info "===================="
    
    cd ${SCRIPT_DIR}/U-boot
    make distclean
    info "U-Boot 清理完成!"
}

# 编译 U-Boot
build_uboot() {
    info "===================="
    info "开始编译 U-Boot..."
    info "===================="
    
    # 切换到 U-Boot 源码目录
    cd ${SCRIPT_DIR}/U-boot

    # 清理之前的编译产物，确保干净的编译环境
    make distclean

    # 加载 RK3562 默认配置文件
    make rk3562_defconfig
    
    # 编译
    ./make.sh CROSS_COMPILE=aarch64-none-linux-gnu- rk3562 --spl-new
    
    # 复制文件到 Image 目录，方便打包
    info "复制 U-Boot 文件到 Image 目录..."
    mkdir -p ${SCRIPT_DIR}/rockchip/output/Image
    cp -f ${SCRIPT_DIR}/U-boot/uboot.img ${SCRIPT_DIR}/rockchip/output/Image/uboot.img 2>/dev/null || true
    cp -f ${SCRIPT_DIR}/U-boot/rk3562_spl_loader_v1.05.106.bin ${SCRIPT_DIR}/rockchip/output/Image/MiniLoaderAll.bin 2>/dev/null || true
    
    info "U-Boot 编译完成!"
    info "输出文件:"
    ls -alh uboot.img rkbin/idblock.img rk3562_spl_loader_v1.05.106.bin 2>/dev/null || true
}



# 清理 Linux 内核
clean_kernel() {
    info "===================="
    info "清理 Linux 内核..."
    info "===================="
    执行如下命令，配置交叉编译工具链环境变量并清理内核。
    make ARCH=arm64 distclean
    cd ${SCRIPT_DIR}/Kernel
    make distclean
    info "Linux 内核清理完成!"
}

# 内核 menuconfig 配置
menuconfig_kernel() {
    info "===================="
    info "启动内核 menuconfig..."
    info "===================="
    
    cd ${SCRIPT_DIR}/Kernel
    
    # 如果已有配置文件则加载，否则使用默认配置
    if [ -f .config ]; then
        info "检测到已有配置，加载现有配置..."
    else
        info "加载默认配置 (tl3562-evm)..."
        make rk3562_linux_dictpen_defconfig
    fi
    
    # 启动 menuconfig
    info "启动 menuconfig 界面..."
    make menuconfig
    
    # 检查用户是否保存了配置
    if [ -f .config ]; then
        info "内核配置完成!"
        info "配置已保存到 .config"
        
        # 询问是否保存为默认配置
        read -p "是否将当前配置保存为默认配置? (y/N): " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            info "保存为默认配置..."
            make savedefconfig
            cp defconfig arch/arm64/configs/rk3562_linux_dictpen_defconfig
            info "默认配置已更新到 arch/arm64/configs/rk3562_linux_dictpen_defconfig"
        fi
    else
        warn "未检测到 .config 文件，配置可能未保存"
    fi
}

# 编译 Linux 内核
build_kernel() {
    info "===================="
    info "开始编译 Linux 内核..."
    info "===================="
    
    cd ${SCRIPT_DIR}/Kernel
    
    # 配置
    info "配置内核 (tl3562-evm)..."
    make rockchip_linux_defconfig
    
    # 编译内核
    info "编译内核 (使用 8 线程)..."
    make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- tl3562-evm-sdio-wifi.img
    
    # 复制文件到 Image 目录，方便打包
    info "复制内核文件到 Image 目录..."
    mkdir -p ${SCRIPT_DIR}/rockchip/output/Image
    cp -f ${SCRIPT_DIR}/Kernel/boot.img ${SCRIPT_DIR}/rockchip/output/Image/boot.img 2>/dev/null || true
    
    info "Linux 内核编译完成!"
    info "输出文件:"
    ls -lh boot.img arch/arm64/boot/Image 2>/dev/null || true
}

# 构建 Ubuntu 根文件系统并创建软链接
build_ubuntu() {
    info "===================="
    info "构建 Ubuntu 根文件系统..."
    info "===================="
    

    # 复制文件到 Image 目录，方便打包
    info "复制根文件系统到 Image 目录..."
    mkdir -p ${SCRIPT_DIR}/rockchip/output/Image
    
    # 查找生成的根文件系统镜像并复制
    if [ -f ${SCRIPT_DIR}/rk3562-ubuntu20.04-sdk/output/rootfs.img ]; then
        cp -f ${SCRIPT_DIR}/rootfs/rootfs.img ${SCRIPT_DIR}/rockchip/output/Image/rootfs.img 2>/dev/null || true
        info "rootfs.img 已复制"
    fi
    
    
    info "Ubuntu 根文件系统构建完成!"
    info "输出文件:"
    ls -lh ${SCRIPT_DIR}/rootfs/rootfs.img 2>/dev/null || true
}

# 清理全部
clean_all() {
    info "清理全部组件..."
    clean_uboot
    clean_kernel
    info "全部清理完成!"
}

# 编译 forlinx test tools
build_forlinx_cmd() {
    info "===================="
    info "开始编译 Forlinx 测试工具..."
    info "===================="
    
    # 设置工具链
    TOOLCHAIN_PATH="${SCRIPT_DIR}/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin"
    export PATH="${TOOLCHAIN_PATH}:$PATH"
    export CROSS_COMPILE=aarch64-none-linux-gnu-
    
    # 进入测试工具目录
    cd ${SCRIPT_DIR}/app/forlinx/forlinx_cmd
    
    # 编译
    make clean
    make all
    
    # 复制到 output 目录
    mkdir -p ${SCRIPT_DIR}/rockchip/output/Image
    for bin in fltest_keytest fltest_uarttest fltest_spidev_test fltest_watchdog fltest_watchdogrestart; do
        if [ -f "$bin" ]; then
            cp -f "$bin" ${SCRIPT_DIR}/rockchip/output/Image/
            info "已复制 $bin"
        fi
    done
    
    info "Forlinx 测试工具编译完成!"
}

# 打包镜像
build_updateimg() {
    info "===================="
    info "开始打包固件镜像..."
    info "===================="
    cd ${SCRIPT_DIR}/rockchip
    ./mkimage.sh pack
    info "打包完成!"
    info "输出文件:"
    ls -lh ${SCRIPT_DIR}/rockchip/output/update/Image/update.img 2>/dev/null || true
}

# 编译全部并打包
build_all() {
    info "编译全部组件..."
    info "开始编译 U-Boot..."
    build_uboot
    info "开始编译 kernel..."
    build_kernel
    info "开始编译 Ubuntu 根文件系统..."
    build_ubuntu
    info "开始打包..."
    build_updateimg
    info "全部编译完成!"
}



# 显示帮助
show_help() {
    echo "RK3562 SDK 编译脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "编译选项:"
    echo "  uboot         只编译 U-Boot"
    echo "  kernel        只编译 Linux 内核"
    echo "  ubuntu        构建 Ubuntu 根文件系统"
    echo "  all           编译 U-Boot 和内核"
    echo ""
    echo "打包选项:"
    echo "  updateimg     打包固件镜像 (update.img)"
    echo ""
    echo "配置选项:"
    echo "  menuconfig    配置内核选项 (图形界面)"
    echo ""
    echo "清理选项:"
    echo "  clean-uboot   清理 U-Boot"
    echo "  clean-kernel  清理 Linux 内核"
    echo "  clean-all     清理全部"
    echo ""
    echo "其他选项:"
    echo "  forlinx-cmd   编译 Forlinx 测试工具"
    echo "  help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 uboot         # 编译 U-Boot"
    echo "  $0 kernel        # 编译内核"
    echo "  $0 ubuntu        # 构建 Ubuntu 根文件系统"
    echo "  $0 all           # 编译全部"
    echo "  $0 updateimg     # 打包固件镜像"
    echo "  $0 menuconfig    # 配置内核选项"
    echo "  $0 clean-uboot   # 清理 U-Boot"
    echo "  $0 clean-kernel  # 清理内核"
    echo "  $0 clean-all     # 清理全部"
}

# 主函数
main() {
    # 检查参数
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # 设置工具链
    setup_toolchain
    
    case "$1" in
        uboot)
            build_uboot
            ;;
        kernel)
            build_kernel
            ;;
        ubuntu)
            build_ubuntu
            ;;
        updateimg)
            build_updateimg
            ;;
        all)
            build_all
            ;;
        clean-uboot)
            clean_uboot
            ;;
        clean-kernel)
            clean_kernel
            ;;
        clean-all)
            clean_all
            ;;
        menuconfig)
            menuconfig_kernel
            ;;
        forlinx-cmd)
            build_forlinx_cmd
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

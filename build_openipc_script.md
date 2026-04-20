# OpenIPC 固件编译指南

**适用平台**：开源 IP 摄像头固件
**官方仓库**：https://github.com/OpenIPC/firmware

## 一、环境要求

### 1.1 硬件要求
- x86_64 架构计算机（不支持 ARM 架构）
- 建议 16GB+ 内存
- 至少 100GB 可用磁盘空间

### 1.2 系统要求
- Ubuntu 22.04 LTS 或更高版本（推荐）
- 不支持 Ubuntu 20.04

---

## 二、安装编译依赖

### 2.1 方法一：使用 make deps（推荐）
```bash
sudo make deps
```

### 2.2 方法二：手动安装
```bash
sudo apt-get install -y automake autotools-dev bc build-essential cpio \
curl file fzf git libncurses-dev libtool lzop make rsync unzip wget libssl-dev
```

---

## 三、获取源码

```bash
mkdir -p mylocalOpenIPC/src
cd mylocalOpenIPC/src
git clone https://github.com/OpenIPC/firmware.git
cd openipc-firmware
```

---

## 四、配置下载缓存（可选但推荐）

在 `~/.profile` 中添加：
```bash
# Buildroot directory for OpenIPC build
BR2_DL_DIR="${HOME}/buildroot_dl"
[ ! -d "$BR2_DL_DIR" ] && mkdir -p $BR2_DL_DIR
export BR2_DL_DIR
```

使配置生效：
```bash
source ~/.profile
```

---

## 五、编译固件

### 5.1 查看可用目标
```bash
make
```

目标命名格式：`vendor_soc_flavor`
- **vendor**：厂商（如 hisilicon、goke、 Ingenic 等）
- **soc**：芯片型号（如 hi3516cv300、gk7205v200 等）
- **flavor**：版本类型
  - `Lite`：适用于 8MB Flash 的精简版
  - `Ultimate`：适用于 16MB+ Flash 的完整版

### 5.2 选择目标并编译
例如，编译海思 Hi3516CV300 Lite 版：
```bash
make hisilicon_hi3516cv300_lite
```

### 5.3 图形化配置
```bash
make menuconfig
```

---

## 六、常见问题

### 6.1 交叉编译工具链无法执行
**现象**：
```
Cannot execute cross-compiler '/path/to/arm-openipc-linux-musleabi-gcc.br_real'
```

**原因**：主机架构与工具链不兼容

**修复方法**：
- 确保使用 x86_64 架构计算机
- 确保使用 Ubuntu 22.04 LTS

### 6.2 工具链权限问题
```bash
ch chmod +x /path/to/toolchain/*
```

---

## 七、固件输出

编译完成后，固件位于 `output/images/` 目录：
```bash
ls output/images/
```

生成的固件文件格式：
- `.tgz`：完整固件包
- `.bin`：可直接烧录的镜像

---

## 八、烧录固件

### 8.1 通过 TFTP 烧录
需要 TFTP 服务器，将固件放到 TFTP 目录，然后通过 U-Boot 烧录。

### 8.2 通过编程器烧录
使用编程器直接烧录 .bin 文件到 Flash。

---

## 九、默认登录信息

| 服务 | 用户名 | 密码 |
|------|--------|------|
| SSH | root | 12345 |
| Web UI | root | 12345 |

---

## 快捷命令汇总

```bash
# 1. 安装依赖
sudo make deps

# 2. 获取源码
git clone https://github.com/OpenIPC/firmware.git
cd openipc-firmware

# 3. 清理并准备
make clean
make prepare

# 4. 图形化配置
make menuconfig

# 5. 编译
make hisilicon_hi3516cv300_lite
```

---

## 参考资料

- 官方 Wiki：https://github.com/OpenIPC/wiki
- 固件仓库：https://github.com/OpenIPC/firmware
- 设备支持列表：https://openipc.org/

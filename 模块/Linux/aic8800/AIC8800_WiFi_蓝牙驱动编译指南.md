# AIC8800 WiFi/蓝牙驱动编译与部署指南

## 一、驱动简介

AIC8800 是一款支持 WiFi 和蓝牙的无线芯片，提供 SDIO 和 USB 两种接口版本：
- **SDIO 版本**：支持 WiFi + 蓝牙，功能完整
- **USB 版本**：仅支持 WiFi

## 二、内核是否有AIC8800驱动

**内核中没有集成 AIC8800 驱动**，需要单独编译。

检查方法：
```bash
# 检查内核源码中是否有aic8800驱动
grep -r 'AIC8800\|aic8800' /workspace/RK35xx/kernel-6.1/ --include='*.c' --include='*.h'

# 检查内核配置
grep -i 'CONFIG_AIC8800' /workspace/RK35xx/kernel-6.1/.config
```

结果：
- ✅ 内核已启用 SDIO 接口支持
- ❌ 内核源码中没有 aic8800 驱动代码
- ❌ 内核配置中没有 CONFIG_AIC8800 相关配置

## 三、驱动源码位置

驱动源码位于 SDK 的 `external/rkwifibt/drivers/` 目录下：

```
external/rkwifibt/drivers/
├── aic8800_sdio/     # SDIO 版本驱动
│   ├── aic8800_bsp.ko    # 底层 BSP 驱动
│   ├── aic8800_fdrv.ko   # WiFi 功能驱动
│   └── aic8800_btlpm.ko  # 蓝牙电源管理驱动
└── aic8800_usb/     # USB 版本驱动
    ├── aic_load_fw.ko    # 固件加载驱动
    └── aic8800_fdrv.ko   # WiFi 功能驱动
```

## 四、编译 SDIO 版本驱动

### 4.1 修改 Makefile

编辑 `external/rkwifibt/drivers/aic8800_sdio/Makefile`，修改 `CONFIG_PLATFORM_ROCKCHIP` 部分：

```makefile
ifeq ($(CONFIG_PLATFORM_ROCKCHIP), y)
ARCH = arm64
KDIR ?= /workspace/RK35xx/kernel-6.1
CROSS_COMPILE ?= /workspace/RK35xx/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
ccflags-y += -DCONFIG_PLATFORM_ROCKCHIP
endif
```

> **注意**：路径 `/workspace` 是 Docker 容器内 SDK 的挂载路径

### 4.2 执行编译

```bash
cd external/rkwifibt/drivers/aic8800_sdio
make clean
make -j$(nproc)
```

### 4.3 编译结果

编译成功后生成三个驱动模块：
```
aic8800_bsp/aic8800_bsp.ko
aic8800_fdrv/aic8800_fdrv.ko
aic8800_btlpm/aic8800_btlpm.ko
```

## 五、编译 USB 版本驱动

### 5.1 编译 aic_load_fw

```bash
cd aic_load_fw
make ARCH=arm64 \
  CROSS_COMPILE=/workspace/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- \
  KDIR=/workspace/kernel-6.1
```

### 5.2 复制符号表

```bash
cp Module.symvers ../aic8800_fdrv/
```

### 5.3 编译 aic8800_fdrv

```bash
cd ../aic8800_fdrv
make ARCH=arm64 \
  CROSS_COMPILE=/workspace/RK35xx/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- \
  KDIR=/workspace/RK35xx/kernel-6.1
```

## 六、部署到目标设备

### 6.1 传输驱动模块

从主机通过 scp 传输驱动模块到目标设备：

```bash
scp aic8800_bsp.ko aic8800_fdrv.ko aic8800_btlpm.ko linaro@192.168.2.111:/tmp/
```

### 6.2 安装固件

```bash
# 复制固件目录
sudo cp -r ./fw/aic8800DC /lib/firmware/

# 复制 udev 规则
sudo cp aic.rules /lib/udev/rules.d/
```

### 6.3 加载驱动模块

SDIO 版本按顺序加载：

```bash
sudo insmod /tmp/aic8800_bsp.ko
sudo insmod /tmp/aic8800_fdrv.ko
sudo insmod /tmp/aic8800_btlpm.ko
```

### 6.4 验证加载状态

```bash
lsmod | grep aic
```

或者查看内核日志：

```bash
dmesg | grep aic
```

## 七、WiFi 测试方法

### 7.1 查看驱动加载状态
```bash
# 查看模块加载
lsmod | grep aic

# 查看网络接口
ip link show
iw dev
```

### 7.2 连接 WiFi
```bash
# 扫描 WiFi 网络
iw wlan0 scan | grep SSID

# 连接 WiFi（假设 ssid 是 MyWiFi）
wpa_passphrase MyWiFi password | sudo tee /etc/wpa_supplicant/wpa_supplicant.conf
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
sudo dhclient wlan0

# 或者使用 nmcli
nmcli device wifi connect MyWiFi password password
```

## 八、蓝牙测试方法

### 8.1 检查蓝牙设备
```bash
# 查看蓝牙设备
hciconfig

# 检查蓝牙驱动
lsmod | grep aic8800_btlpm
```

### 8.2 启动蓝牙
```bash
# 启动蓝牙控制器
sudo hciconfig hci0 up

# 查看设备信息
sudo hciconfig -a
```

### 8.3 蓝牙扫描测试
```bash
# 扫描附近蓝牙设备
sudo hcitool scan

# 查看扫描结果
sudo hcitool lescan  # 低功耗蓝牙扫描
```

## 九、常见问题

### 问题1：驱动加载报 Exec format error

**现象**：
```
insmod: ERROR: could not insert module: Exec format error
```

**原因**：编译驱动所用内核版本与目标设备运行的内核版本不匹配

**修复方法**：确认目标设备内核版本 `uname -r`，使用对应版本内核源码重新编译驱动

---

### 问题2：aic8800 SDIO 与 USB 驱动符号冲突

**现象**：
```
aic8800_bsp: exports duplicate symbol aicwf_prealloc_txq_alloc (owned by aic_load_fw)
```

**原因**：SDIO 驱动（`aic8800_bsp`）和 USB 驱动（`aic_load_fw`）都导出了相同符号，两套驱动不能同时加载

**修复方法**：先卸载 USB 驱动，再加载 SDIO 驱动

```bash
sudo rmmod aic8800_fdrv aic_load_fw
sudo insmod /tmp/aic8800_bsp.ko
sudo insmod /tmp/aic8800_fdrv.ko
sudo insmod /tmp/aic8800_btlpm.ko
```

---

### 问题2：WiFi 无法连接

**检查步骤**：

1. 确认驱动加载成功：
```bash
lsmod | grep aic
```

2. 确认固件已加载：
```bash
ls /lib/firmware/aic8800DC/
```

3. 检查网络接口：
```bash
ip link show
iw dev
```

4. 查看内核日志：
```bash
dmesg | grep -i wifi
```

---

### 问题3：蓝牙无法使用

**检查步骤**：

1. 确认蓝牙电源管理驱动加载：
```bash
lsmod | grep aic8800_btlpm
```

2. 检查蓝牙设备：
```bash
hciconfig
```

3. 启动蓝牙：
```bash
sudo hciconfig hci0 up
```

---

## 十、一键编译脚本

### 10.1 SDIO 驱动编译脚本

创建文件 `build_aic8800_sdio.sh`：

```bash
#!/bin/bash

SDK_DIR="/workspace/RK35xx"
DRIVER_DIR="$SDK_DIR/external/rkwifibt/drivers/aic8800_sdio"

echo "===== 开始编译 AIC8800 SDIO 驱动 ====="

cd $DRIVER_DIR

echo "===== 清理旧文件 ====="
make clean

echo "===== 开始编译 ====="
make -j$(nproc)

echo "===== 编译完成 ====="
echo "生成的文件："
ls -la aic8800_bsp/*.ko aic8800_fdrv/*.ko aic8800_btlpm/*.ko 2>/dev/null

echo "===== 固件位置 ====="
echo "固件目录: $DRIVER_DIR/fw/aic8800DC"
ls -la $DRIVER_DIR/fw/aic8800DC/
```

### 10.2 使用方法

```bash
# 赋予执行权限
chmod +x build_aic8800_sdio.sh

# 执行编译
./build_aic8800_sdio.sh
```

---

## 十一、固件文件说明

### 11.1 WiFi 固件

固件文件位于驱动目录的 `fw/aic8800DC/` 子目录：

```
fw/aic8800DC/
├── aic8800_sdio_chip_config.bin
├── aic8800_sdio_fw.bin
├── aic8800_sdio_rf.bin
└── aic8800_bt_fw.bin
```

### 11.2 蓝牙固件

蓝牙固件文件：
- `aic8800_bt_fw.bin` - 蓝牙固件

---

## 十二、注意事项

1. **内核版本匹配**：驱动模块必须与目标设备运行的内核版本完全匹配
2. **加载顺序**：SDIO 驱动必须按顺序加载（bsp → fdrv → btlpm）
3. **不能同时加载**：SDIO 和 USB 驱动不能同时加载，会产生符号冲突
4. **固件路径**：固件必须放在 `/lib/firmware/aic8800DC/` 目录
5. **权限问题**：编译驱动时确保内核源码目录有写权限

---

## 十三、参考命令速查

```bash
# 编译驱动
cd external/rkwifibt/drivers/aic8800_sdio
make clean && make -j$(nproc)

# 传输到目标设备
scp aic8800_bsp.ko aic8800_fdrv.ko aic8800_btlpm.ko user@192.168.x.x:/tmp/

# 加载驱动
sudo insmod aic8800_bsp.ko
sudo insmod aic8800_fdrv.ko
sudo insmod aic8800_btlpm.ko

# 查看加载状态
lsmod | grep aic
dmesg | grep aic

# 卸载驱动
sudo rmmod aic8800_btlpm aic8800_fdrv aic8800_bsp

# 检查 WiFi 接口
iw dev
ip link show wlan0

# 检查蓝牙设备
hciconfig
```

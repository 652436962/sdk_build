# HDC 安装指南

## 简介

HDC（HarmonyOS Device Connector）是用于与鸿蒙设备通信的工具。本指南说明如何在 Linux 系统上安装 hdc。

## 环境

- 操作系统：Linux
- 工具链目录：`/home/lechi/Desktop/toolchains-linux-x64-26.0.0.24-Beta/toolchains`

## 安装步骤

### 1. 复制 hdc 可执行文件到系统路径

```bash
sudo cp /path/to/toolchains/hdc /usr/local/bin/hdc
sudo chmod +x /usr/local/bin/hdc
```

### 2. 复制依赖的动态库到系统库目录

```bash
sudo cp /path/to/toolchains/libusb_shared.so /usr/local/lib/
```

### 3. 更新动态库缓存

```bash
sudo ldconfig
```

### 4. 验证安装

```bash
hdc --version
```

输出类似 `Ver: 3.2.0d` 表示安装成功。

## 依赖项

| 文件 | 说明 |
|------|------|
| `hdc` | 主程序可执行文件 |
| `libusb_shared.so` | USB 通信依赖库 |

## 故障排除

### USB 设备权限问题

如果 `hdc list targets` 显示 `[Empty]`，但 `lsusb` 能看到设备（如 `ID 12d1:5000 Huawei Technologies Co., Ltd. "HDC Device"`），需要添加 udev 规则：

```bash
sudo bash -c 'cat > /etc/udev/rules.d/99-hdc.rules << EOF
# Huawei HDC Device
SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", MODE="0666", GROUP="plugdev"
EOF'
```

重载 udev 规则并重新插拔 USB 设备：

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb
```

将当前用户添加到 plugdev 组（如未加入）：

```bash
sudo usermod -a -G plugdev $USER
```

然后重新登录或重启。

### libusb_shared.so 找不到

如果遇到 `libusb_shared.so: cannot open shared object file` 错误，确保：
1. 动态库已复制到 `/usr/local/lib/`
2. 已执行 `sudo ldconfig` 更新缓存
3. 可用 `ldconfig -p | grep libusb` 检查库是否被系统识别
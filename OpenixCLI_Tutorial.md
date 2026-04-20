# OpenixCLI 全志烧录工具

**OpenixCLI** 是一款开源的命令行固件烧录工具，专为全志（Allwinner）芯片设备设计。支持 FEL（USB Boot）模式和 FES（U-Boot）模式，提供完整的固件部署解决方案。

**项目地址**：https://github.com/YuzukiTsuru/OpenixCLI

---

## 功能特性

| 功能 | 说明 |
|------|------|
| 设备扫描 | 自动检测已连接的全志设备 |
| 固件烧录 | 支持多种模式烧录固件镜像 |
| FEL/FES 支持 | 支持 FEL（USB Boot）和 FES（U-Boot）两种设备模式 |
| 写入校验 | 可选启用写入校验，确保数据完整性 |
| 进度跟踪 | 可视化烧录进度指示 |
| 分区烧录 | 可烧录特定分区或完整固件 |
| 详细日志 | 支持详细调试输出 |

---

## 安装

### 前提条件

- Rust 工具链（1.70 或更高版本）
- libusb 开发库

### 从源码编译

```bash
# 克隆仓库
git clone https://github.com/YuzukiTsuru/OpenixCLI
cd OpenixCLI

# 编译
cargo build --release

# 编译后的二进制文件位于 target/release/openixcli
```

### Linux 系统依赖（Ubuntu/Debian）

```bash
sudo apt install libusb-1.0-0-dev pkg-config
```

---

## 使用方法

### 扫描设备

列出所有已连接的全志设备：

```bash
openixcli scan
```

### 烧录固件

将固件烧录到设备：

```bash
openixcli flash <firmware_file> [options]
```

### 烧录选项

| 选项 | 简写 | 说明 |
|------|------|------|
| `--bus` | `-b` | USB 总线号 |
| `--port` | `-P` | USB 端口号 |
| `--verify` | `-V` | 写入后启用校验（默认：true） |
| `--mode` | `-m` | 烧录模式 |
| `--partitions` | `-p` | 要烧录的分区（逗号分隔） |
| `--post-action` | `-a` | 烧录后动作 |
| `--verbose` | `-v` | 启用详细输出 |

### 烧录模式

| 模式 | 说明 |
|------|------|
| `partition` | 仅烧录特定分区 |
| `keep_data` | 烧录时保留用户数据 |
| `partition_erase` | 擦除并烧录特定分区 |
| `full_erase` | 烧录前完全擦除（默认） |

### 烧录后动作

| 动作 | 说明 |
|------|------|
| `reboot` | 烧录完成后重启（默认） |
| `poweroff` | 烧录完成后关机 |
| `shutdown` | 烧录完成后关闭 |

---

## 烧录示例

### 烧录固件到指定设备

```bash
openixcli flash firmware.img --bus 1 --port 5
```

### 仅烧录特定分区

```bash
openixcli flash firmware.img --partitions "boot,system"
```

### 禁用写入校验

```bash
openixcli flash firmware.img --verify false
```

### 烧录完成后关机

```bash
openixcli flash firmware.img --post-action poweroff
```

---

## 设备模式

OpenixCLI 支持以下设备模式：

- **FEL (USB Boot)**：初始启动模式，用于固件烧录
- **FES (U-Boot)**：加载 U-Boot 后的二级模式
- **UPDATE_COOL / UPDATE_HOT**：更新模式

---

## 常用命令速查

```bash
# 扫描设备
openixcli scan

# 烧录固件（完整擦除）
openixcli flash firmware.img

# 烧录固件（保留数据）
openixcli flash firmware.img --mode keep_data

# 烧录后重启
openixcli flash firmware.img --post-action reboot

# 详细输出模式
openixcli flash firmware.img --verbose
```

---

## 注意事项

1. 设备需要进入 FEL 或 FES 模式才能烧录
2. 某些操作可能需要 root 权限（sudo）
3. 烧录过程中请勿断开设备连接
4. 建议在烧录前备份重要数据

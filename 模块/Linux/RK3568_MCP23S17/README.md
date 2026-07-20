# RK3568 MCP23S17 SPI GPIO 扩展芯片

## 概述

MCP23S17 通过 SPI0 总线连接 RK3568，提供 16 路扩展 GPIO（GPA0~GPA7 / GPB0~GPB7）。

## 设备树配置

| 配置文件 | 适用内核 | 描述 |
|----------|----------|------|
| `0001-mcp23s17-spi.dts` | Linux 5.10 | SPI0 挂载 MCP23S17，最高 1MHz |

```bash
# 将节点内容复制到对应设备树中
# &spi0 节点追加 mcp23s17 子节点
```

源码见 [0001-mcp23s17-spi.dts](0001-mcp23s17-spi.dts)。

## 驱动排查

### 确认驱动已启用

```bash
zcat /proc/config.gz | grep MCP23
# 应显示 CONFIG_GPIO_MCP23S08=y 或 =m
```

如果没有，需在内核中启用并重新编译：

```bash
make menuconfig
```

路径：

```
Device Drivers --->
    Pin controllers --->
        <*> Microchip MCP23S08 I/O expander
```

> **注意**：该驱动同时支持 `mcp23s08` 和 `mcp23s17`，内核配置及日志中名称均以 `mcp23s08` 表示。

### 确认 SPI probe 成功

```bash
ls /sys/bus/spi/devices/           # 应有 spi0.0
ls -l /sys/bus/spi/devices/spi0.0/driver
```

### 确认 GPIO 控制器已注册

```bash
grep . /sys/class/gpio/gpiochip*/label
# 应显示 mcp23s17
```

## 引脚映射（基址 496）

| 组 | 引脚 | GPIO 编号 |
|----|------|-----------|
| GPA | GPA0~GPA7 | 496~503 |
| GPB | GPB0~GPB7 | 504~511 |

## GPIO 控制

```bash
# 手动控制
echo 504 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio504/direction
echo 1 > /sys/class/gpio/gpio504/value

# 脚本控制（见 gpio.sh）
./gpio.sh 504 1
./gpio.sh 504 0
```

源码见 [gpio.sh](gpio.sh)。

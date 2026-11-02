# 翻斗式脉冲雨量计

## 概述

将 RK3562 平台 GPIO0_A0 引脚配置为翻斗式脉冲雨量计输入，通过 gpio-keys 框架捕获翻斗脉冲，应用层统计脉冲次数换算降雨量。

## 硬件连接

| 引脚 | 功能 | 说明 |
|------|------|------|
| GPIO0_A0 | 脉冲输入 | 翻斗每翻转一次产生一个脉冲，低电平有效 |

## 补丁说明

| 补丁文件 | 适用内核 | 描述 |
|----------|----------|------|
| `0001-rain-gauge-gpio-keys.dts` | Linux 5.10 | 将 GPIO0_A0 从门磁传感器迁移为雨量计，10ms 去抖 |

```bash
# 将节点内容复制到 tl3562-evm.dts 中
# rain_gauge 节点放入根节点下，gpio-keys pinctrl 节点放入 &pinctrl 下
```

## 设备树变更

```dts
rain_gauge: gpio-keys {
    compatible = "gpio-keys";
    pinctrl-names = "default";
    pinctrl-0 = <&gpio_key_pin>;
    rain_gauge_key: rain-gauge {
        label = "tipping-bucket-rain-gauge";
        linux,code = <KEY_PROG1>;
        gpios = <&gpio0 RK_PA0 GPIO_ACTIVE_LOW>;
        debounce-interval = <10>;
    };
};
```

## 验证

```bash
# 查看设备是否注册
cat /proc/bus/input/devices | grep -A1 "gpio-keys"

# 监听脉冲事件（eventX 替换为实际设备号）
hexdump /dev/input/event3
```

## 测试程序

`rain_gauge.c` 每分钟统计一次脉冲数并换算为降雨量，即使无脉冲也会准时输出。

### 编译

```bash
aarch64-none-linux-gnu-gcc -o rain_gauge rain_gauge.c -static -s
```

### 运行

```bash
# 前台运行（Ctrl+C 停止）
./rain_gauge

# 自定义每斗雨量（默认 0.25mm）
./rain_gauge 0.2

# 后台运行
nohup ./rain_gauge > /tmp/rain.log 2>&1 &
```

### 输出示例

```
[雨量计] 每斗=0.25mm  统计周期=60s  设备=/dev/input/event3
[2026-07-20 10:30:00] 本分钟脉冲=12  分钟雨量=3.0mm  累计脉冲=12  累计雨量=3.0mm
[2026-07-20 10:31:00] 本分钟脉冲=0   分钟雨量=0.0mm  累计脉冲=12  累计雨量=3.0mm
```

源码见 [rain_gauge.c](rain_gauge.c)。

## 降雨量换算

```
降雨量(mm) = 脉冲次数 × 每斗雨量(mm)
```

每斗雨量由雨量计硬件规格决定，常见值为 0.2mm / 0.25mm / 0.5mm。

## 相关文件

- 设备树：`tl3562-evm.dts` L62-L72
- 外设测试：`GY-C100D_外设测试.md` 7.7 节
- 设备树记录：`rk3562设备树修改记录.md`

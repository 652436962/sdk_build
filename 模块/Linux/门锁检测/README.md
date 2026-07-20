# 门锁检测

## 概述

将 RK3562 平台 GPIO0_A0 引脚配置为门锁检测输入，通过 gpio-keys 框架捕获锁状态变化，应用层实时输出锁定/解锁事件。

## 硬件连接

| 引脚 | 功能 | 说明 |
|------|------|------|
| GPIO0_A0 | 输入中断 | 门锁状态检测，低电平有效 |

## 设备树配置

| 配置文件 | 适用内核 | 描述 |
|----------|----------|------|
| `0001-door-lock-gpio-keys.dts` | Linux 5.10 | 将 GPIO0_A0 配置为门锁检测输入，10ms 去抖 |

```bash
# 将节点内容复制到 tl3562-evm.dts 中
# door_lock 节点放入根节点下，gpio-keys pinctrl 节点放入 &pinctrl 下
```

## 设备树变更

```dts
door_lock: gpio-keys {
    compatible = "gpio-keys";
    pinctrl-names = "default";
    pinctrl-0 = <&gpio_key_pin>;
    door_lock_key: door-lock {
        label = "door-lock";
        linux,code = <KEY_PROG1>;
        gpios = <&gpio0 RK_PA0 GPIO_ACTIVE_LOW>;
        debounce-interval = <10>;
    };
};
```

## 验证

```bash
# 查看设备是否注册
cat /proc/bus/input/devices | grep -A1 -B1 "door-lock"

# 监听原始事件（eventX 替换为实际设备号）
hexdump /dev/input/event3
```

## 测试程序

`door_lock.c` 实时监听门锁状态变化，输出锁定/解锁事件及时间戳。

### 编译

```bash
aarch64-none-linux-gnu-gcc -o door_lock door_lock.c -static -s
```

### 运行

```bash
# 前台运行（Ctrl+C 停止）
./door_lock

# 后台运行
nohup ./door_lock > /tmp/door_lock.log 2>&1 &
```

### 输出示例

```
[门锁检测] 设备=/dev/input/event3  等待状态变化...
[2026-07-20 15:30:05] 门锁状态: 锁定
[2026-07-20 15:31:12] 门锁状态: 解锁
[2026-07-20 15:32:08] 门锁状态: 锁定
```

源码见 [door_lock.c](door_lock.c)。

## 相关文件

- 设备树：`tl3562-evm.dts` L57-L73
- 外设测试：`GY-C100D_外设测试.md`
- 设备树记录：`rk3562设备树修改记录.md`

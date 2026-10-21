# T527 硬件看门狗测试

T527（飞凌 OKT527-C **A1 版本**）板载硬件看门狗（HW watchdog）的测试脚本。

> 参考：`openharmony_T527/GY-C220D_采集器硬件外设.md` →「A1版本添加硬件看门狗」

## 硬件

| 功能 | 引脚 | GPIO 编号 | 电平/时序 |
|------|------|-----------|-----------|
| 供电 | PE8 | `gpio136` | 输出高电平为看门狗供电 |
| 喂狗 | PE7 | `gpio135` | 周期翻转（高/低），间隔须 < 超时 |
| 超时 | — | — | **60S** |

硬件看门狗需要持续翻转 PE7，若超过 60S 无翻转则触发板子复位。脚本默认每 **30S** 翻转一次。

## 用法

```sh
# 上电并启动后台喂狗（每 30S 翻转 PE7）
sudo sh watchdog-test.sh start

# 查看 gpio136/gpio135 状态与喂狗进程
sudo sh watchdog-test.sh status

# 手动喂狗一次（翻转 PE7）
sudo sh watchdog-test.sh feed

# 停止喂狗并断电（安全停止，不会复位）
sudo sh watchdog-test.sh stop

# 复位测试：保持供电但停止喂狗，约 60S 后板子应自动重启
sudo sh watchdog-test.sh test 70

# 放开两个 GPIO 的文件权限（之后可免 root 操作）
sudo sh watchdog-test.sh perm
```

## 移植到其它开发板

引脚编号与时序都集中在脚本顶部的「板级硬件配置（宏定义）」一节，换板子只改这几行：

| 宏 | 说明 | 默认值 |
|----|------|--------|
| `WDT_BOARD` | 目标板卡 | `OKT527-C (A1)` |
| `WDT_PWR_PIN` / `WDT_PWR_GPIO` | 供电引脚名 / GPIO 号 | `PE8` / `136` |
| `WDT_FEED_PIN` / `WDT_FEED_GPIO` | 喂狗引脚名 / GPIO 号 | `PE7` / `135` |
| `WDT_TIMEOUT` | 看门狗超时（秒） | `60` |
| `WDT_HALF` | 喂狗翻转半周期（秒） | `30` |

> 注意：`WDT_HALF` 必须小于 `WDT_TIMEOUT`，否则看门狗会因超时未喂狗而触发复位。

## 手动等效命令

与参考文档中一致的原始操作：

```sh
# 1. 看门狗供电（PE8 = gpio136）
echo 136 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio136/direction
echo 1   > /sys/class/gpio/gpio136/value

# 2. 喂狗循环（每 30 秒翻转一次 PE7 = gpio135）
echo 135 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio135/direction
while true; do
    echo 1 > /sys/class/gpio/gpio135/value; sleep 30
    echo 0 > /sys/class/gpio/gpio135/value; sleep 30
done &
```

## 权限说明

写 GPIO 的 `value` / `direction` 需要 root 权限。三种处理方式：

1. **直接 sudo 运行**（最简单）；
2. 先执行 `sudo sh watchdog-test.sh perm`，把 `gpio135`/`gpio136` 的 `value`、`direction` 权限放开为 `666`；
3. 配置 udev 规则持久化（推荐量产环境）：

   ```sh
   # /etc/udev/rules.d/99-gpio.rules
   SUBSYSTEM=="gpio", MODE="0666"
   ```

## 注意事项

- `stop` 会把 PE8 拉低断电，看门狗停止工作（**安全**，不会复位）；
- `test` 保持供电、仅停止喂狗，才会触发复位——用于验证看门狗是否真正生效；
- 若 `export` 后 `gpioN` 目录迟迟不出现，检查设备树中该 GPIO 是否已被其他功能占用；
- 仅适用于 **A1 版本**板子（早期版本无此硬件看门狗）。

# RTL8723DS SDIO（TF 卡总线）检测命令

> 用途：在新固件（RTL8723DS 挂在 TF 卡 SDIO 总线 `sdmmc0`/`mmc1`，默认上电、常驻）上，逐项确认模组是否被枚举、驱动是否绑定。
> 环境：TL3562-EVM-SDIO-WIFI，内核 `5.10.209`；串口 `115200`，登录 `root` / `lechi@2024`。

## 0. 关键背景（本板）

| 项 | 值 |
|----|----|
| WiFi 所在控制器 | `sdmmc0` = `ff880000.mmc` = `mmc1`（TF 卡槽总线） |
| 供电方式 | 默认上电（`vmmc=vcc3v3_sd`、`vqmmc=vccio_sd`），**非 GPIO 控制** |
| 模组属性 | 常驻（`non-removable`） |
| 驱动 | `rtl8723ds`（内建，`CONFIG_RTL8723DS=y`） |
| 设备树文件 | `tl3562-evm-sdio-wifi.dts` |

---

## 1. 系统与内核版本

```sh
uname -a
cat /proc/device-tree/model; echo
```

- 期望：`TL3562-EVM-SDIO-WIFI`；内核编译时间应为最新一次编译。

## 2. TF/SDIO 控制器（`mmc1` = `sdmmc0`）枚举检查

```sh
# 控制器当前工作状态
cat /sys/kernel/debug/mmc1/ios

# 控制器下挂的子设备（有卡会看到 mmc1:xxxx）
ls /sys/class/mmc_host/mmc1/

# 启动日志（重点看有没有 new SDIO card / voltages / error -110）
dmesg | grep -iE "mmc[0-9]|sdmmc|sdio|voltages|new .*card|non-removable" | head -50
```

- **成功标志**：`ios` 里 `clock` 非 0、`power mode: 2 (on)`、`bus width: 4 (4 bits)`；日志出现 `mmc1: new ... SDIO card` 之类。
- **失败标志**：`clock: 0 Hz`、`power mode: 0 (off)`；`ls` 只有 `device power subsystem uevent`（无卡）；日志只有 `Bus speed ... 400000/300000/200000/100000Hz` 反复重试。

## 3. SDIO 设备节点与驱动绑定

```sh
# SDIO 设备是否注册
ls /sys/bus/sdio/devices/

# 若上面有 1-1:xxxx 之类，查看其驱动
for d in /sys/bus/sdio/devices/*; do echo "$d -> $(readlink -f $d/driver 2>/dev/null)"; done
```

- **成功标志**：`/sys/bus/sdio/devices/` 下有设备，且 `driver` 指向 `rtl8723ds`。
- **失败标志**：目录为空。

## 4. 网络接口

```sh
ls /sys/class/net
ip -br link 2>/dev/null || ifconfig -a
# 若出现 wlan0：
ip -br addr show wlan0
readlink -f /sys/class/net/wlan0/device
```

- **成功标志**：出现 `wlan0`，且 `device` 指向 `.../ff880000.mmc/mmc_host/mmc1/1-1:xxxx`。
- **失败标志**：只有 `eth0/eth1/lo`。

## 5. rtl8723ds 驱动日志与版本

```sh
dmesg | grep -iE "rtw|8723|sdio" | tail -40
strings /proc/kallsyms >/dev/null 2>&1   # 内建驱动，无需 .ko
```

- **成功标志（部分）**：`RTW: rtl8723ds v5.13.5-91-...` 已加载；绑定后出现 `rtw_drv_probe`/`register netdev wlan0` 等。
- 注意：**仅驱动加载（module init）不代表枚举成功**，必须配合第 2/3/4 节。

## 6. 引脚复用 / 电源核对

```sh
# sdmmc0 引脚是否 mux 到控制器
grep -i sdmmc0 /sys/kernel/debug/pinctrl/*/pinmux-pins

# TF 相关电源
cat /sys/kernel/debug/regulator/vcc3v3_sd/state 2>/dev/null
cat /sys/kernel/debug/regulator/vccio_sd/state  2>/dev/null

# GPIO 扩展器（PCA9555）状态：505..510
grep -iE "gpio-50[0-9]|gpio-51[0-9]" /sys/kernel/debug/gpio 2>/dev/null
```

- 期望：`pin 43-48 (gpio1-11..16)` = `ff880000.mmc function sdmmc0`；电源 on。
- 说明：本板 8723 为**默认上电**，`506/507/508`（wifi disable/reset/power）**不需要**手动控制。

## 7. 重新触发枚举（可选）

```sh
# 重新加载 mmc1 宿主（等效重插卡）
echo ff880000.mmc > /sys/bus/platform/drivers/dwmmc_rockchip/unbind
sleep 1
echo ff880000.mmc > /sys/bus/platform/drivers/dwmmc_rockchip/bind
sleep 3

dmesg | grep -iE "mmc1|ff880000|sdio|rtw" | tail -20
ls /sys/bus/sdio/devices/
ls /sys/class/net
```

> 注意：`ff880000.mmc` 为 `sdmmc0`（TF）；`ff890000.mmc` 为 `sdmmc1`（本板已 disabled）。

## 8. 一键采集（建议整段执行并回贴）

```sh
{
  echo "== uname =="; uname -a
  echo "== model =="; cat /proc/device-tree/model; echo
  echo "== mmc1 ios =="; cat /sys/kernel/debug/mmc1/ios 2>/dev/null
  echo "== mmc1 child =="; ls /sys/class/mmc_host/mmc1/ 2>/dev/null
  echo "== sdio devs =="; ls /sys/bus/sdio/devices/ 2>/dev/null
  echo "== net =="; ls /sys/class/net 2>/dev/null
  echo "== pinmux sdmmc0 =="; grep -i sdmmc0 /sys/kernel/debug/pinctrl/*/pinmux-pins 2>/dev/null
  echo "== dmesg mmc =="; dmesg | grep -iE "mmc[0-9]|sdmmc|sdio|voltages|rtw|8723" | tail -60
} 2>&1
```

---

## 判定表

| 现象 | 含义 | 下一步 |
|------|------|--------|
| `mmc1` 有 `new ... SDIO card` + `sdio/devices` 有设备 + 驱动为 `rtl8723ds` + 出现 `wlan0` | ✅ 成功 | 用 `iw`/`wpa_supplicant` 联网测试 |
| `mmc1` 只有 `Bus speed ...` 重试，无 `new card` | ❌ 卡未应答 | 查模组是否插好/是否为该总线；对比电源/时钟；可能需要 32.768kHz LPM 或不同复位时序 |
| `mmc1` 无任何 `Bus speed`、`power off` | ❌ 控制器没扫卡 | 查 `status` 是否 okay、时钟/复位 |
| 有 SDIO 设备但驱动不是 `rtl8723ds` | ⚠️ 绑定异常 | 查 `VID/PID` 是否匹配 `rtl8723ds` 驱动表 |

## 附：串口工具

```sh
# 串口设备（可能因重插变化）
ls /dev/ttyUSB*
# 波特率 115200，登录 root / lechi@2024
# 若被终端占用会提示 busy，需先关闭占用程序
```

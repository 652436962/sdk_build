# RTL8723DS 集成 —— 实机烧录后检查记录

> 日期：2026-10-08
> 设备：TL3562-EVM-SDIO-WIFI，IP `192.168.1.102`
> 登录：`ssh root@192.168.1.102`（密码 `lechi@2024`）
> 目的：确认新固件中 RTL8723DS 驱动是否工作
> 结论速览：**驱动已成功编入并加载（版本正确）；但 SDIO 总线枚举失败（`mmc2: error -110`），WiFi 未拉起。失败发生在驱动层之下（MMC 总线层）。**

证据标注：★ 本次实机实测输出；◎ 由实测/代码推导；○ 判断/推测。

---

## 1. 连通性与系统信息

```bash
ping -c 3 192.168.1.102          # 通，延迟 ~2-5ms
ssh root@192.168.1.102
uname -a
cat /proc/device-tree/model
```

结果：★

```
Linux Lechi 5.10.209-rt89 #13 SMP Thu Oct 8 15:52:08 CST 2026 aarch64
Machine model: TL3562-EVM-SDIO-WIFI
```

- 内核 build 时间 `Oct 8 2026 15:52`，与本次编译产物一致。★

---

## 2. 驱动是否加载（`dmesg`）

```bash
dmesg | grep -iE "8723|rtl|sdio|mmc"
```

结果：★

```
[    0.970845] RTW: module init start
[    0.970848] RTW: rtl8723ds v5.13.5-91-gf00b2a755.20241203_COEX20220930-4541
[    0.970850] RTW: build time: Oct  8 2026 15:52:00
[    0.970852] RTW: rtl8723ds BT-Coex version = COEX20220930-4541
[    0.970889] RTW: module init ret=0
```

- RTL8723DS 驱动已编入内核并完成 init，版本与目标一致。★

设备树芯片类型：★

```
[WLAN_RFKILL]: wlan_platdata_parse_dt: wifi_chip_type = rtl8723ds
/proc/device-tree/wireless-wlan/wifi_chip_type -> "rtl8723ds"
```

---

## 3. SDIO 总线枚举（核心问题）

```bash
dmesg | grep -iE "mmc2|sdio"
ls /sys/bus/sdio/devices/
```

结果：★

```
[    1.038587] dwmmc_rockchip ff890000.mmc: allocated mmc-pwrseq
[    1.038599] mmc_host mmc2: card is non-removable.
[    1.258792] mmc_host mmc2: Bus speed (slot 0) = 400000Hz
[    1.277004] dwmmc_rockchip ff890000.mmc: card claims to support voltages below defined range
[    1.288764] mmc_host mmc2: Bus speed (slot 0) = 50000000Hz
[    1.288895] mmc2: error -110 whilst initialising SDIO card
（随后 300k/200k/100k 依次重试，均在切到 50MHz 后报 -110）
```

- `mmc2` = `ff890000.mmc` = **sdmmc1**（SDIO WiFi 控制器）。★
- `/sys/bus/sdio/devices/` **为空**，即 SDIO 卡未枚举成功。★
- `/sys/kernel/debug/mmc2/ios`：`power mode: 0 (off)`、`vdd: 0 (invalid)`。★

分析（◎）：报文 `card claims to support voltages below defined range` 出自内核
`drivers/mmc/core/core.c:1123` 的 `mmc_select_voltage()`，发生在收到 CMD5 响应、解析 OCR 之后；
说明**卡在 400kHz 能应答**，但主机切到 50MHz 后续命令超时（-110）。

---

## 4. `wlan0/wlan1` 身份核对（排除误判）

```bash
ls /sys/class/net
readlink -f /sys/class/net/wlan0/device
```

结果：★

```
wlan0 wlan1
wlan0 -> /sys/devices/platform/fed00000.usb/usb1/1-1/1-1.4/1-1.4:1.0
```

- `wlan0/wlan1` 挂在 **USB 总线**（`1-1.4:1.0`），**不是** SDIO 的 RTL8723DS。◎
- 即：当前可用的无线接口来自 USB 网卡，与本次集成的 SDIO 驱动无关。◎

---

## 5. 电源 / 复位 / rfkill 检查

```bash
cat /sys/kernel/debug/gpio | grep -iE "reset|pwr|wifi"
ls /sys/bus/i2c/devices/
cat /sys/class/rkwifi/wifi_power
```

结果：★

```
gpio-507 ( |reset) out lo ACTIVE LOW      # PCA9555 IO1_4 = sdio_pwrseq 的 reset
i2c devices: ... 1-0020 (pca9555) ...
/sys/class/rkwifi/wifi_power = 0
```

- `sdio_pwrseq` 复位脚 `PCA_IO1_4` 经 PCA9555（i2c 1-0020）映射为 gpio-507；当前状态 `out lo`（低有效≈复位断言）。★
- `rfkill list` 无输出。★
- dmesg 中 `rfkill_wlan_probe` → `rfkill_set_wifi_bt_power: 1`，但 `wifi_power` 读回仍为 0。★

### 尝试：手动上电 + 重新枚举

```bash
echo 1 > /sys/class/rkwifi/wifi_power          # 上电，读回 1
echo ff890000.mmc > /sys/bus/platform/drivers/dwmmc_rockchip/unbind
echo ff890000.mmc > /sys/bus/platform/drivers/dwmmc_rockchip/bind
```

结果：★

- gpio-507 状态仍为 `out lo`（未变化）。
- `mmc2` 重新初始化，仍 `error -110`，`/sys/bus/sdio/devices/` 依旧为空。
- ◎ 说明：单纯切换 `wifi_power` 未能让 SDIO 枚举成功。

---

## 6. 现状判断

| 项 | 结论 | 证据 |
|----|------|------|
| RTL8723DS 驱动编入内核 | ✅ 成功 | ★ dmesg 版本串、`CONFIG_RTL8723DS=y` |
| 设备树芯片类型 | ✅ 已是 `rtl8723ds` | ★ `/proc/device-tree` |
| SDIO 卡枚举 | ❌ 失败（`-110`） | ★ 无 `/sys/bus/sdio/devices` |
| `wlan0/wlan1` | 非本次驱动（USB） | ★ sysfs 设备路径 |
| 失败层级 | MMC 总线层，**在驱动代码之上游** | ◎ |

---

## 7. 待验证假设（均未定论，需下一步实验）

> 以下为排查方向，非结论。○

- **H1｜SDIO 信号/时钟**：卡在 400kHz 应答、切 50MHz 后超时，可能是信号完整性或该模组对 50MHz 支持问题。
  验证：把 `&sdmmc1` 的 `max-frequency` 降到 `25000000`（或更低）重编 dtb 试。
- **H2｜供电/复位时序**：`sdio_pwrseq` 复位脚是否被正确释放、模组供电是否真正到位。
  验证：测量模组供电与复位脚波形；确认 `tl3562-evm.dts` 删除 `sdio_pwrseq` 的 `clocks`（32.768kHz LPO）是否影响该模组。
- **H3｜模组本身/装配**：模组是否为 RTL8723DS、是否插接良好、是否与该 EVB 的 SDIO 接口匹配。
  验证：核对该 EVB 官方 SDIO WiFi 模组型号与用户所用模组；与厂家确认。
- **H4｜我们启用的 `wireless-wlan`（rfkill_wlan）影响**：vendor 版 `tl3562-evm-sdio-wifi.dts` **只使能 `sdmmc1`+`sdio_pwrseq`，未使能 `wireless-wlan`**；我们为设 `wifi_chip_type` 把它使能了。
  验证：把 `wireless-wlan` 改回 `disabled`（保持 `sdmmc1` 使能）重编 dtb 试。
  ※ 注意：RTL8723DS 驱动源码中 `get_wifi_chip_type()` 调用是注释掉的，驱动**并不依赖**该属性。◎

---

## 8. 复现命令汇总（供厂家/他人复测）

```bash
ssh root@<设备IP>            # 密码 lechi@2024
uname -a
cat /proc/device-tree/model
dmesg | grep -iE "8723|rtl|sdio|mmc2"
ls /sys/bus/sdio/devices/
readlink -f /sys/class/net/wlan0/device
cat /sys/kernel/debug/gpio
cat /sys/kernel/debug/mmc2/ios
cat /sys/class/rkwifi/wifi_power
# 重新触发枚举：
echo ff890000.mmc > /sys/bus/platform/drivers/dwmmc_rockchip/unbind
echo ff890000.mmc > /sys/bus/platform/drivers/dwmmc_rockchip/bind
```

---

## 9. 本次未做的检查（盲区声明）

- 未用示波器/逻辑分析仪测量 SDIO 时钟、CMD/DAT 与模组供电、复位波形。○
- 未做「降低 SDIO 时钟」「回退 DTS 的 `wireless-wlan`」两组对照实验（需重编并重烧）。○
- 未与厂家确认该 EVB 官方支持的 SDIO WiFi 模组型号。○
- 未验证模组物理插接状态（远程无法操作）。○

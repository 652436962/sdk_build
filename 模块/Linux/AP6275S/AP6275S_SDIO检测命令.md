# AP6275S SDIO 检测命令

> 板端：RK3562 / TL3562-EVM（hostname `Lechi`），root 登录。用于判断模组是否上电、SDIO 是否识别、驱动/固件是否加载。

## 1. 模组是否上电 / 被 SDIO 枚举

```sh
# SDIO 设备列表（应有 1 个，vendor/device 见下）
ls /sys/bus/sdio/devices/
for d in /sys/bus/sdio/devices/*; do
  echo "$d vendor=$(cat $d/vendor) device=$(cat $d/device)"; done
```
- Broadcom 厂商 `0x02d0`；AP6275S（BCM43752）device `0xaae8`。
- **为空 = 模组未被识别**（供电/时钟/WL_REG_ON/SDIO 总线配置问题）。

## 2. SDIO 总线与时钟

```sh
ls /sys/class/mmc_host/                 # mmc0(SD) mmc1(SDIO) ...
dmesg | grep -iE "mmc[0-9]|sdio|dwmmc" | tail -20
cat /sys/kernel/debug/mmc1/ios 2>/dev/null   # clock/bus width/timing/voltage
```
关注：`bus width: 1 bits`（AP6275S 在 TF 座按 **1-bit** 起，4-bit 实测常失败）、`signal voltage: 1.80 V`（模组是 1.8V 信令）、`clock`。

## 3. WL_REG_ON / pwrseq

```sh
dmesg | grep -iE "pwrseq|redis|wifi_enable|WL_REG_ON"
# 若有 GPIO 扩展器(pca9555)，复位脚通常经它控制
i2cdetect -l 2>/dev/null; ls /sys/class/gpio/ 2>/dev/null | head
```

## 4. 驱动 / 固件加载

```sh
lsmod | grep -iE "bcmdhd|dhd"
dmesg | grep -iE "dhd|bcmdhd" | tail -40
ls -l /vendor/etc/firmware/            # 应有 fw_bcm43752a2_ag.bin / nvram_ap6275s.txt / clm_*.blob
```

成功标志：
```
F1 signature OK, socitype:0x1 chip:0xaae8 rev:0x2 pkg:0x4
Final fw_path=/vendor/etc/firmware/fw_bcm43752a2_ag.bin
Final nv_path=/vendor/etc/firmware/nvram_ap6275s.txt
NVRAM version:  AP6275S_NVRAM_V1.2.1_...
Firmware up: op_mode=0x0005, MAC=...
```

## 5. 接口 / 扫描

```sh
ifconfig -a | grep -A2 wlan0
ifconfig wlan0 up
iw dev
iw dev wlan0 scan | grep -E "SSID|signal" | head
```

## 6. 常见失败与判定

| 现象 | 可能原因 |
|------|----------|
| `/sys/bus/sdio/devices/` 为空 | WL_REG_ON 没拉高 / SDIO 总线未使能 / 时钟或 1.8V 电源域 / 模组未插好 / 无 32.768K 晶振 |
| `F1 signature ... 0x00000000` | SDIO 通信失败（供电/时序/走线） |
| `dhdsdio_htclk: HT Avail timeout` | 缺 32.768KHz 晶振，连续两次 `wlan0 down/up` 试试 |
| `Failed to init Power On` / `rtw_hal_init fail` | （Realtek 类）驱动/供电问题，可重启复位 |
| `Final fw_path` 指向不存在文件 | `/vendor/etc/firmware/` 缺 AP6275S 固件 |
| `TX FAILED ... ERR=-84` | SDIO 引脚驱动能力不足，调整 pinctrl drive-strength |

## 7. 一键速查

```sh
echo "SDIO:";      ls /sys/bus/sdio/devices/
echo "mmc:";       ls /sys/class/mmc_host/
echo "driver:";    lsmod | grep -iE "bcmdhd|dhd"
echo "fw:";        ls -l /vendor/etc/firmware/ 2>/dev/null
echo "dhd log:";   dmesg | grep -iE "dhd|bcmdhd" | tail -15
echo "iface:";     ifconfig -a | grep -iE "^wlan|^p2p"
```

# AP6275S（SDIO WiFi，Broadcom BCM43752）集成说明

> 平台：RK3562 / TL3562-EVM（GY-100D），Ubuntu 20.04，内核 `5.10.209-rt89`
> 模组：正基 **AP6275S**（Broadcom **BCM43752**，SDIO WiFi + UART/PCM BT，Wi-Fi 5）
> 驱动：Rockchip `bcmdhd` **101.10.361.36 (r892223-20231107-1)**（仅 WiFi）
> 目录用途：RK3562 SDK 上 AP6275S SDIO WiFi 的驱动、固件、设备树与集成资料

## 一、文件索引

| 文件/目录 | 说明 |
|-----------|------|
| `bcmdhd.101.10.591.x.rk/` | 新版 bcmdhd 驱动源码（用于替换 SDK 内 `rkwifi/bcmdhd`） |
| `bcmdhd.101.10.591.x.rk.20231107-1.7z` | 驱动原包 |
| `firmware/` | AP6275S 固件（放到板端 `/vendor/etc/firmware/`） |
| `dts/tl3562-evm-sdio-wifi.dts` | 本板 AP6275S 设备树覆盖（SDIO + pwrseq + ap6275s） |
| `AP6275S_集成计划.md` | 集成方案与步骤 |
| `AP6275S_改动明细.md` | 逐条改动明细 |
| `AP6275S_SDIO检测命令.md` | 串口/SDIO 检测命令与判定 |

## 二、关键信息

| 项 | 值 |
|----|----|
| 芯片 | Broadcom BCM43752（SDIO ID `0x02d0:0xaae8`，rev 2） |
| 驱动 | `bcmdhd`（SDIO + OOB 中断），源码目录 `.../rkwifi/bcmdhd/` |
| 固件名映射 | `dhd_config.c`：`{BCM43752_CHIP_ID, 2, "bcm43752a2_ag", "ap6275s"}` |
| 固件路径 | `CONFIG_BCMDHD_FW_PATH="/vendor/etc/firmware/fw_bcmdhd.bin"`（实际用 `fw_bcm43752a2_ag.bin`） |
| 内核配置 | `CONFIG_BCMDHD=y` `CONFIG_AP6XXX=m` `CONFIG_BCMDHD_SDIO=y` |

## 三、固件（`firmware/` → 板端 `/vendor/etc/firmware/`）

```
fw_bcm43752a2_ag.bin        # WiFi 固件（必须）
nvram_ap6275s.txt           # NVRAM 校准（必须）
clm_bcm43752a2_ag.blob      # CLM 法规（必须）
fw_bcm43752a2_ag_apsta.bin  # AP/STA 并发固件（可选）
fw_bcm43752a2_ag_mfg.bin    # 产测固件（可选）
```

**拷贝来源（rkwifibt）**：
```
ok3562_sdk/OK3562-linux-source/external/rkwifibt/firmware/broadcom/AP6275S/wifi/
rk3562_buildroot/rk3562_linux_sdk_release/external/rkwifibt/firmware/broadcom/AP6275S/wifi/
```
（本目录 `firmware/` 即取自上述 `external/rkwifibt/firmware/broadcom/AP6275S/wifi/`；
本板 SDK `rk3562_sdk/ubuntu` 树内无此固件，需从 rkwifibt 引过来。）

> 驱动按芯片自动选名：最终会用 `fw_bcm43752a2_ag.bin` + `nvram_ap6275s.txt`。

## 四、设备树（`dts/tl3562-evm-sdio-wifi.dts`）

```dts
/* vccio_sd 只给 sdmmc0 做 vqmmc -> 直接钉死 1.8V，让 TF 座 IO 跑 1.8V */
&vccio_sd {
	regulator-min-microvolt = <1800000>;
	regulator-max-microvolt = <1800000>;
};

&sdmmc0 {                       /* 模组插在 TF 卡座，SDIO 走 TF 总线 sdmmc0（mmc1） */
	/delete-property/ no-sdio;
	no-sd;
	bus-width = <4>;
	cap-sdio-irq;
	keep-power-in-suspend;
	non-removable;
	max-frequency = <50000000>;
	vqmmc-supply = <&vccio_sd>;  /* ★ 1.8V（上面钉死） */
	/* 不要加 mmc-pwrseq：WL_REG_ON 已由 R113 常接到 1.8V */
	status = "okay";
};
&sdmmc1 { status = "disabled"; };   /* 原厂 SDIO 控制器未用 */

&sdio_pwrseq { status = "disabled"; };

&{/wireless-wlan} {
	status = "okay";
	wifi_chip_type = "ap6275s";     /* 关键 */
	/* 最小可用：WL_HOST_WAKE 悬空 -> in-band 中断，删掉 OOB 相关 */
	/delete-property/ WIFI,host_wake_irq;
	/delete-property/ pinctrl-names;
	/delete-property/ pinctrl-0;
};
```

> **1.8V 信令（关键）**：AP6275S 测试板（TF 卡形态）的 SDIO 是 **1.8V 信令**
> （CMD/DAT 上拉 R120~R125 到 VDD_1V8，模组 VDDIO=1.8V，板载 RT9013 由 3.3V 转 1.8V）。
> 本板 `sdmmc0` 的 `vqmmc` 是 `vccio_sd`（rk809 LDO_REG5，1.8~3.3V 可调），但 Tronlong 的 dts 删了
> `sd-uhs-sdr104`（保持 3.3V 给 TF 卡）。
> - 只加回 `sd-uhs-sdr104` 不够：1.8V 切换要**等卡应答后**才做，1.8V 模组在 3.3V 就不应答 → 死锁。
> - 因此**直接把 `vccio_sd` 钉成 1.8V**（该 regulator 仅给 sdmmc0 用），TF 座 IO 从一开始就是 1.8V。

> **最小可用接法**：`WL_REG_ON` 常高（原理图 R113 0R 已贴到 1.8V）、`WL_HOST_WAKE` 悬空。
> 对应软件：dts **不加 pwrseq**、**删掉 OOB host-wake**；驱动改用 **in-band 中断**
> （`rkwifi/bcmdhd/Makefile` 注释掉 `CONFIG_BCMDHD_OOB := y` → 走 `-DSDIO_ISR_THREAD`），
> 并保证 dts 有 `cap-sdio-irq`。

> **总线确认**：AP6275S 模组**插在本板 TF 卡卡槽**上，SDIO 走 `sdmmc0`（`mmc1`，`ff880000.mmc`）。
> 普通 TF 卡在该座可正常识别（硬件 OK）。

## 五、驱动替换

SDK 原 `rkwifi/bcmdhd` 版本 `101.10.361.18 (2022-05-19)`，替换为 `101.10.361.36 (2023-11-07)`：

```bash
R=<SDK>/ubuntu/Kernel/drivers/net/wireless/rockchip_wlan/rkwifi
cp -a $R/bcmdhd $R/bcmdhd.orig        # 备份
rm -rf $R/bcmdhd && cp -a bcmdhd.101.10.591.x.rk $R/bcmdhd
```

## 六、编译与烧录

```bash
cd <SDK>/ubuntu
./build.sh kernel        # 生成 boot.img（含 tl3562-evm-sdio-wifi.dtb + bcmdhd.ko）
./build.sh all           # 或全量：uboot + kernel + rootfs
```

固件放入 rootfs 的 `/vendor/etc/firmware/`（制作/挂载 rootfs.img 时复制），再打包烧录。

## 七、上电验证

```bash
ifconfig wlan0 up                 # 触发 dhd 上电加载固件
dmesg | grep -iE "dhd|bcmdhd"     # 关键日志：
#   F1 signature OK, socitype:0x1 chip:0xaae8 rev:0x2
#   Final fw_path=/vendor/etc/firmware/fw_bcm43752a2_ag.bin
#   Final nv_path=/vendor/etc/firmware/nvram_ap6275s.txt
#   Firmware up: op_mode=..., MAC=...
iw dev                            # 出现 wlan0
```

## 八、待办 / 未覆盖

- [ ] 硬件总线/引脚确认（见第四节 ⚠️）
- [ ] 编译内核 + 替换固件 + 烧录后实机验证（`wlan0` / 扫描 / AP）
- [ ] AP 模式脚本（可复用 `../RTL8723DS/ap/wifi_ap.sh`）
- [ ] 32.768KHz 晶振：无外接时需连续两次 `wlan0 down/up` 才能起（见博客）
- [ ] BT：AP6275S 的 BT 走 UART/PCM，本目录仅 WiFi

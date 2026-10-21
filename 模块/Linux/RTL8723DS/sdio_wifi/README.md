# sdio_wifi 备份说明

> 备份时间：2026-10-09
> 备份对象：把 RTL8723DS v5.13.5 集成进 RK3562 Ubuntu SDK 后的“当前 WiFi 改动文件”
> 备份来源根：`rk3562_sdk/ubuntu/`
> 本备份位置：`/media/lechi/linuxsdk/linuxsdk/模块/Linux/RTL8723DS/sdio_wifi/`

## 内容

### 1. `changed/` —— 改动文件（保持 SDK 内相对路径）

| 备份路径 | 对应 SDK 路径 | 改动点 |
|----------|---------------|--------|
| `changed/build.sh` | `ubuntu/build.sh` | 内核目标 `tl3562-evm.img` → `tl3562-evm-sdio-wifi.img` |
| `changed/Kernel/arch/arm64/configs/rockchip_linux_defconfig` | 同 | 关闭 `CONFIG_RTL8189FS`，新增 `CONFIG_RTL8723DS=y` |
| `changed/Kernel/arch/arm64/boot/dts/rockchip/tl3562-evm-sdio-wifi.dts` | 同 | 新增 `&{/wireless-wlan}`（status okay + `wifi_chip_type="rtl8723ds"`） |
| `changed/Kernel/drivers/net/wireless/rockchip_wlan/Kconfig` | 同 | 新增 `source ".../rtl8723ds/Kconfig"` |
| `changed/Kernel/drivers/net/wireless/rockchip_wlan/Makefile` | 同 | 新增 `obj-$(CONFIG_RTL8723DS) += rtl8723ds/` |
| `changed/Kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/Makefile` | 同 | Rockchip 平台适配（`CONFIG_PLATFORM_ARM_RK3188=y`、`MODULE_NAME := 8723ds` 等）+ `-Daes_encrypt=rtw_crypto_aes_encrypt` |
| `changed/Kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/Kconfig` | 同 | `---help---` → `help`（内核 5.10 kconfig 语法） |

### 2. `rtl8723ds_v5.13.5_src.tar.gz` —— 驱动源码快照（615 项）

- 内容：`rockchip_wlan/rtl8723ds/` 的**源码**（已排除编译产物 `*.o`/`.*.cmd`/`*.ko`/`*.a`/`modules.order`/`Module.symvers`）。
- 版本：`include/rtw_version.h` → `v5.13.5-91-gf00b2a755.20241203_COEX20220930-4541`。
- 上游原始包：`模块/Linux/RTL8723DS/RTL8723DS_WiFi_linux_v5.13.5-91.../WiFi/...tar.gz`。

## 还原方法

```bash
SDK=/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu
B=/media/lechi/linuxsdk/linuxsdk/模块/Linux/RTL8723DS/sdio_wifi
cp -a "$B/changed/build.sh" "$SDK/build.sh"
cp -a "$B/changed/Kernel/arch/arm64/configs/rockchip_linux_defconfig" "$SDK/Kernel/arch/arm64/configs/"
cp -a "$B/changed/Kernel/arch/arm64/boot/dts/rockchip/tl3562-evm-sdio-wifi.dts" "$SDK/Kernel/arch/arm64/boot/dts/rockchip/"
cp -a "$B/changed/Kernel/drivers/net/wireless/rockchip_wlan/Kconfig" "$SDK/Kernel/drivers/net/wireless/rockchip_wlan/"
cp -a "$B/changed/Kernel/drivers/net/wireless/rockchip_wlan/Makefile" "$SDK/Kernel/drivers/net/wireless/rockchip_wlan/"
cp -a "$B/changed/Kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/Makefile" "$SDK/Kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/"
cp -a "$B/changed/Kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/Kconfig" "$SDK/Kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/"
tar -xzf "$B/rtl8723ds_v5.13.5_src.tar.gz" -C "$SDK/Kernel/drivers/net/wireless/rockchip_wlan/"   # 会覆盖 rtl8723ds/
```

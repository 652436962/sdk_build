# RTL8723DS WiFi v5.13.5 集成 —— 逐条改动明细

> 对应计划：`RTL8723DS_v5.13.5_集成计划.md`
> 执行日期：2026-10-08
> 编译结果：**成功**（容器 `rk3562-sdk`，`EXIT=0`，产出 `boot.img` 40MB，含 `tl3562-evm-sdio-wifi.dtb`）
> 说明：`rk3562_sdk/` 在仓库 `.gitignore` 内，以下改动不被 git 跟踪。

## 一、计划内改动

| # | 位置 | 原文问题 | 修改内容 | 理由 | 证据 |
|---|------|----------|----------|------|------|
| 1 | `rk3562_sdk/ubuntu/Kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/` | 原为旧版 v5.10.1 驱动，且未接入构建 | 删除原内容，解包 v5.13.5 源码整体覆盖 | 沿用原目录名（“原来有就用原来的”），升级到目标版本 | ★ 实测 `rtw_version.h` 由 `v5.10.1-20-...` 变为 `v5.13.5-91-gf00b2a755.20241203_COEX20220930-4541` |
| 2a | 同上 `Makefile:151` | `CONFIG_PLATFORM_I386_PC = y`（默认 PC 平台） | 改为 `= n` | 目标为 ARM64 嵌入式平台，关闭 x86 默认平台 | ★ 文件实测 |
| 2b | 同上 `Makefile:176` | `CONFIG_PLATFORM_ARM_RK3188 = n` | 改为 `= y` | 启用 Rockchip 平台分支（定义 `CONFIG_PLATFORM_ROCKCHIPS` 等），与树内原驱动一致 | ★ 文件实测 |
| 2c | 同上 `Makefile:1719` | RK3188 段启用 `-DRTW_ENABLE_WIFI_CONTROL_FUNC` | 注释该行 | 该宏会让驱动匹配全部 SDIO WLAN class 设备，且依赖平台电源控制；与树内旧版处理一致 | ★ 文件实测；◎ 与旧版对照 |
| 2d | 同上 `Makefile:1727` | RK3188 段 `MODULE_NAME := wlan` | 改为 `MODULE_NAME := 8723ds` | 保证 Kbuild 目标 `obj-$(CONFIG_RTL8723DS) := $(MODULE_NAME).o` 生成正确的对象名/模块名 | ★ 文件实测；★ 树内旧版同位置即为 `8723ds` |
| 3 | 同上 `Kconfig` | v5.13.5 自带 Kconfig 使用 `---help---` 语法 | 改写为 `# SPDX-License-Identifier: GPL-2.0` + `help` | 内核 5.10 kconfig 已不支持 `---help---`，会导致 `rockchip_linux_defconfig` 直接语法报错 | ★ 编译日志：`Kconfig:4: syntax error` / `unknown statement "---help---"` |
| 4 | `.../rockchip_wlan/Kconfig` | 未包含 rtl8723ds 的 Kconfig | 在 `if RTL_WIRELESS_SOLUTION` 内新增 `source "drivers/net/wireless/rockchip_wlan/rtl8723ds/Kconfig"` | 使 `CONFIG_RTL8723DS` 可在内核配置中出现 | ★ 文件实测（第 45 行） |
| 5 | `.../rockchip_wlan/Makefile` | 无 rtl8723ds 目标 | 新增 `obj-$(CONFIG_RTL8723DS) += rtl8723ds/` | 纳入内核编译 | ★ 文件实测（第 6 行） |
| 6 | `arch/arm64/configs/rockchip_linux_defconfig` | 无 RTL8723DS 配置 | 新增 `CONFIG_RTL8723DS=y` | 驱动编入内核 | ★ 编译后 `.config` 实测 |
| 7 | 同上 | `CONFIG_RTL8189FS=y` | 改为 `# CONFIG_RTL8189FS is not set` | 经用户决策（选项 A）：`rtl8189fs` 与 `rtl8723ds` 同名全局符号冲突，二者不能同时编入 vmlinux，故关闭 8189FS | ★ 编译日志：`multiple definition of 'SetPacketRx' ... rtl8723ds vs rtl8189fs`；★ 编译后 `System.map` 中 8189fs 符号数为 0 |
| 8 | `arch/arm64/boot/dts/rockchip/tl3562-evm-sdio-wifi.dts` | 仅使能 `sdmmc1/sdio_pwrseq`，未使能 `wireless-wlan`、`wifi_chip_type` 仍继承 `rtl8189fs` | 新增 `&{/wireless-wlan} { status = "okay"; wifi_chip_type = "rtl8723ds"; };` | 使 SDIO WiFi 节点生效并把芯片类型标为 rtl8723ds | ★ 文件实测；★ 编译后 dtb 中可检出 `rtl8723ds` |
| 9 | `rk3562_sdk/ubuntu/build.sh:157` | 内核编译目标 `tl3562-evm.img`（默认 dtb，SDIO 关闭） | 改为 `tl3562-evm-sdio-wifi.img` | 选项 B：默认产物即使用带 SDIO WiFi 的设备树 | ★ 文件实测；★ 编译产物为 `tl3562-evm-sdio-wifi.dtb` |

## 二、计划外必需的修复（原计划未预见，编译暴露）

| # | 位置 | 原文问题 | 修改内容 | 理由 | 证据 |
|---|------|----------|----------|------|------|
| E1 | 同上 `rtl8723ds/Kconfig` | 见上表第 3 条 | 同第 3 条 | 同第 3 条 | ★ 编译日志 |
| E2 | 同上 `Makefile:2436` | 驱动内置的 wpa_supplicant AES 实现定义全局符号 `aes_encrypt`，与内核 `lib/crypto/aes.c` 的 `aes_encrypt` 同名，编入 vmlinux 时冲突 | 新增 `EXTRA_CFLAGS += -Daes_encrypt=rtw_crypto_aes_encrypt`（宏重命名，仅影响该模块内该符号；未采用 `rtw_aes_encrypt`，因驱动已存在同名函数 `core/rtw_security.c:1590`） | 让驱动可保持 `=y` 编入内核而不与内核 crypto 符号冲突 | ★ 编译日志：`multiple definition of 'aes_encrypt'; rtl8723ds/core/crypto/aes-internal-enc.o vs lib/crypto/aes.o`；★ 重命名后链接成功 |

## 三、对原计划的更正（留痕）

| 项 | 初版计划写法 | 实际情况 | 处理 |
|----|--------------|----------|------|
| 计划第 2 条之一 | 拟在 RK3188 段新增 `-DCONFIG_RESUME_IN_WORKQUEUE`（照抄树内 v5.10） | v5.13.5 的 `drv_conf.h:188` 对该宏有 `#error "enable CONFIG_RESUME_IN_WORKQUEUE without CONFIG_WAKELOCK or CONFIG_ANDROID_POWER..."` 检查，本内核未开 WAKELOCK/ANDROID_POWER，编译失败 | **初版有误，已更正**：最终未添加该宏 |

## 四、编译验证结果

容器 `rk3562-sdk`，执行 `/workspace/ubuntu/build.sh kernel`：

- 结果：`EXIT=0`，`vmlinux` 链接成功，`boot.img (with Image resource.img)` 生成，resource.img 内含 `tl3562-evm-sdio-wifi.dtb`。★
- `.config`：`CONFIG_RTL8723DS=y`、`# CONFIG_RTL8189FS is not set`、`CONFIG_WL_ROCKCHIP=y`。★
- vmlinux 版本串：`v5.13.5-91-gf00b2a755.20241203_COEX20220930-4541`。★
- `System.map`：`rtl8723d` 相关符号 258 个；`8189fs` 符号 0 个。★
- 驱动以 built-in 形式编入（无 `rtl8723ds.ko`）。★

## 五、遗留与未覆盖项

- 未做目标板实机加载/联网功能测试（仅编译级验证）。○
- BT 驱动（`BT/20210416_BT_...v3b3b.tar.gz`）按决策不在本次范围。★
- `rk3562_linux_dictpen_defconfig` 未同步 `CONFIG_RTL8723DS`（`build.sh` 的 menuconfig 分支用此文件；构建实际用 `rockchip_linux_defconfig`）。★
- 本次未创建旧驱动备份（遵循协作规范“不建备份”）。◎

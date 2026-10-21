# RTL8723DS WiFi v5.13.5 驱动集成计划（RK3562 Ubuntu SDK）

> 状态：计划定稿，待执行
> 目标平台：`rk3562_sdk/ubuntu`（RK3562 / RK3562J，Linux 5.10.209，Forlinx/OK3562 Ubuntu 20.04 SDK）
> 编写日期：2026-10-08

## 1. 任务目标

将 datasheet 中的 Realtek RTL8723DS WiFi Linux 驱动 **v5.13.5-91** 集成进 RK3562 Ubuntu SDK 内核树
（`rk3562_sdk/ubuntu/Kernel`），使其被编译进内核，并能驱动 RTL8723DS SDIO WiFi 模组。

## 2. 已确认决策

| 决策项 | 选择 |
|--------|------|
| 集成范围 | 仅 WiFi v5.13.5（不含 BT 包） |
| 集成方式 | 沿用现有 `rtl8723ds` 目录，替换其内容（“原来有就用原来的”） |
| 编译方式 | 编译进内核 `=y` |
| 设备树 | 修改 DTS 并启用 SDIO WiFi |
| 内核产物目标 | 选项 B：把 `build.sh` 默认内核目标切换为 `tl3562-evm-sdio-wifi.img` |
| 编译验证 | 执行内核编译验证 |

## 3. 调研结论（带证据等级）

- **★** 驱动本体位于嵌套包：
  `模块/Linux/RTL8723DS/RTL8723DS_WiFi_linux_v5.13.5-91-gf00b2a755_COEX20220930-4541.20241203/WiFi/RTL8723DS_WiFi_linux_v5.13.5-91-gf00b2a755_COEX20220930-4541.20241203.tar.gz`
  内层为 `driver/rtl8723DS_WiFi_linux_v5.13.5-91-gf00b2a755.20241203_COEX20220930-4541.tar.gz`，含
  `Makefile / Kconfig / core / hal / os_dep / platform / include`。
  `include/rtw_version.h` 确认版本 `DRIVERVERSION "v5.13.5-91-gf00b2a755.20241203_COEX20220930-4541"`。
- **★** SDK 内核为 Linux 5.10.209；Rockchip WLAN 框架位于
  `ubuntu/Kernel/drivers/net/wireless/rockchip_wlan/`。
- **★** 该目录下**已存在** `rtl8723ds/`，但为**旧版 v5.10.1**
  （`include/rtw_version.h` → `v5.10.1-20-g5af20e016.20200310_beta`），且**未接入
  Kconfig/Makefile/defconfig，未被编译**。
- **★** 现有接入参考为 `rtl8189fs`：
  - `rockchip_wlan/Kconfig` 仅 `source ".../rtl8189fs/Kconfig"`；
  - `rockchip_wlan/Makefile` 仅 `obj-$(CONFIG_RTL8189FS) += rtl8189fs/`；
  - `arch/arm64/configs/rockchip_linux_defconfig`：`CONFIG_WL_ROCKCHIP=y`、`CONFIG_WIFI_BUILD_MODULE=y`、`CONFIG_RTL8189FS=y`。
- **★** 新驱动自带 Rockchip 适配：源码含 `CONFIG_PLATFORM_ROCKCHIPS` 分支，且自带 `Kconfig`。
  但其 `Makefile` 默认 `CONFIG_PLATFORM_I386_PC=y`，且 `CONFIG_PLATFORM_ARM_RK3188` 段内为
  `MODULE_NAME := wlan`；树内旧版同位置被改为 `MODULE_NAME := 8723ds` 并调整了若干编译 flag。
- **★** 设备树现状：
  - `arch/arm64/boot/dts/rockchip/tl3562-evm.dts`：`wireless-wlan` 为 `disabled` 且
    `wifi_chip_type = "rtl8189fs"`；`&sdio_pwrseq`、`&sdmmc1` 均为 `disabled`。
  - `arch/arm64/boot/dts/rockchip/tl3562-evm-sdio-wifi.dts`：include `tl3562-evm.dts`，使能
    `&sdio_pwrseq` 与 `&sdmmc1`，但**未**使能 `wireless-wlan`、未改 `wifi_chip_type`。
  - `build.sh` 的 `build_kernel` 固定编译 `tl3562-evm.img`（对应默认 dtb，SDIO WiFi 关闭）。
  - `arch/arm64/boot/dts/rockchip/Makefile` 已声明 `dtb-$(CONFIG_ARCH_ROCKCHIP) += tl3562-evm-sdio-wifi.dtb`。
- **◎** `rk3562_sdk/` 在仓库 `.gitignore` 内，内核源码/DTS/build.sh 改动不会被 git 跟踪。
- **◎** `build.sh` 中 `menuconfig` 分支使用 `rk3562_linux_dictpen_defconfig`，与 `build_kernel`
  使用的 `rockchip_linux_defconfig` 不一致（既有现象，本计划不处理）。

## 4. 改动明细

| # | 位置 | 改动内容 | 理由 |
|---|------|----------|------|
| 1 | `ubuntu/Kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/` | 解嵌套 tar，用 v5.13.5 源码整体覆盖原 v5.10.1 内容 | 目录名/接入结构保留，符合“原来有就用原来的” |
| 2 | 同目录 `Makefile` | `CONFIG_PLATFORM_I386_PC=n`、`CONFIG_PLATFORM_ARM_RK3188=y`；RK3188 段 `MODULE_NAME := wlan` → `:= 8723ds`，注释 `-DRTW_ENABLE_WIFI_CONTROL_FUNC`，新增 `-DCONFIG_RESUME_IN_WORKQUEUE` | 与树内旧版 Rockchip 适配一致，保证模块名/平台正确 |
| 3 | `.../rockchip_wlan/Kconfig` | 在 `if RTL_WIRELESS_SOLUTION` 内增加 `source "drivers/net/wireless/rockchip_wlan/rtl8723ds/Kconfig"` | 让 `CONFIG_RTL8723DS` 可见 |
| 4 | `.../rockchip_wlan/Makefile` | 增加 `obj-$(CONFIG_RTL8723DS) += rtl8723ds/` | 纳入编译 |
| 5 | `arch/arm64/configs/rockchip_linux_defconfig` | 在 `CONFIG_RTL8189FS=y` 同段增加 `CONFIG_RTL8723DS=y` | 驱动编入内核（build.sh 实际使用的 defconfig） |
| 6 | `arch/arm64/boot/dts/rockchip/tl3562-evm-sdio-wifi.dts` | 增加 `&wireless-wlan { status = "okay"; wifi_chip_type = "rtl8723ds"; };` | SDIO WiFi 生效并标注芯片类型 |
| 7 | `ubuntu/build.sh` | `build_kernel` 中 `make ... tl3562-evm.img` → `tl3562-evm-sdio-wifi.img` | 选项 B：默认产物即带 SDIO WiFi |
| 8 | 验证 | 容器 `rk3562-sdk` 内：`make rockchip_linux_defconfig` → `make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- tl3562-evm-sdio-wifi.img`，确认 rtl8723ds 无编译错误 | 编译验证 |

## 5. 编译验证步骤

在容器内执行（容器名 `rk3562-sdk`，工作目录 `/workspace/ubuntu/Kernel`）：

```bash
# 1. 进入容器
docker start rk3562-sdk
docker exec -it rk3562-sdk /bin/bash

# 2. 工具链（如环境已设可跳过）
export PATH=/workspace/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
export CROSS_COMPILE=aarch64-none-linux-gnu-
export ARCH=arm64

# 3. 配置 + 编译（含 modules）
cd /workspace/ubuntu/Kernel
make rockchip_linux_defconfig
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- tl3562-evm-sdio-wifi.img

# 4. 确认驱动是否编入
grep CONFIG_RTL8723DS .config
strings vmlinux | grep -i "v5.13.5-91"
```

> 注：`%.img` 目标在满足 `CONFIG_MODULES=y && MAKE_MODULES=y` 时会连带编译 `modules`；
> RTL8723DS 以 `=y` 编入 vmlinux，无需单独安装 `.ko`。

## 6. 风险与待确认项

- **△（漂移风险低）** v5.13.5 驱动面向 Linux 5.x~6.x，理论上兼容 5.10.209；实际是否与
  Rockchip 5.10 打补丁后的内核存在 API 冲突，须以第 5 节编译结果为准。
- **范围提示**：`rk3562_linux_dictpen_defconfig` 未同步（见 3.◎）；如需同步请另行告知。
- **范围提示**：BT 驱动（`BT/20210416_BT_Android_Linux_Driver_RTL8723D_COEX_v3b3b.tar.gz`）
  按决策不在本次范围。
- 交付时将附**逐条改动明细 + 证据等级**，编译结果如实汇报。

## 7. 交付物

- 修改后的驱动源码与内核配置/设备树/build.sh（位于 `rk3562_sdk/`，不进 git）。
- 本计划文件 + 执行后的改动明细文件。

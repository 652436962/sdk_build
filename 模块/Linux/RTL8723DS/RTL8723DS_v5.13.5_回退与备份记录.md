# RTL8723DS v5.13.5 集成 —— 备份与回退记录

> 日期：2026-10-09
> 要求：备份当前 WiFi 改动（命名 `sdio_wifi`），并把源码/配置恢复为改动前
> 备份位置：`模块/Linux/RTL8723DS/sdio_wifi/`（2026-10-09 最终落位）

---

## 一、备份（已完成）

备份目录：`/media/lechi/linuxsdk/linuxsdk/模块/Linux/RTL8723DS/sdio_wifi/`

| 内容 | 说明 |
|------|------|
| `changed/` | 本次 WiFi 改动的文件（保持 SDK 相对路径），共 7 个文件 ★ |
| `rtl8723ds_v5.13.5_src.tar.gz` | 驱动源码快照（615 项，已排除 `.o/.cmd/.ko` 等编译产物）★ |
| `README.md` | 备份清单与还原方法 |

详见 `模块/Linux/RTL8723DS/sdio_wifi/README.md`。

---

## 二、恢复改动前的源码/配置（已完成）

| # | 文件 | 恢复内容 | 结果 |
|---|------|----------|------|
| 1 | `rk3562_sdk/ubuntu/build.sh` | 内核目标改回 `tl3562-evm.img` | ✅ ★ |
| 2 | `.../arch/arm64/configs/rockchip_linux_defconfig` | 恢复 `CONFIG_RTL8189FS=y`，移除 `CONFIG_RTL8723DS=y` | ✅ ★ |
| 3 | `.../boot/dts/rockchip/tl3562-evm-sdio-wifi.dts` | 移除 `&{/wireless-wlan}` 覆盖块（恢复 vendor 原样：仅使能 `sdio_pwrseq` 与 `sdmmc1`） | ✅ ★ |
| 4 | `.../rockchip_wlan/Kconfig` | 移除 `source ".../rtl8723ds/Kconfig"` | ✅ ★ |
| 5 | `.../rockchip_wlan/Makefile` | 移除 `obj-$(CONFIG_RTL8723DS) += rtl8723ds/` | ✅ ★ |

恢复后核对：`defconfig` 仅 `CONFIG_RTL8189FS=y`；DTS 与 vendor 原样一致；两处 Kconfig/Makefile 引用已移除。★

---

## 三、唯一无法还原的项（重要）

- **旧版 `rtl8723ds/` 驱动源码（v5.10.1）在最初集成时被 v5.13.5 覆盖，且当时未留备份，`rk3562_sdk/` 又在 `.gitignore` 内，无法从 git 找回。** ◎
- 处理方式：**保留现有 `rtl8723ds/` 目录（v5.13.5）但不再接入构建**（Kconfig/Makefile/defconfig 引用均已去除）——即与该目录在改动前“存在但不参与编译”的状态**功能等价**，但**目录内容版本不同**（v5.13.5 vs v5.10.1）。★
- 若你需要彻底移除该目录，或从别处取回 v5.10.1 源码，请告知。

> 备注：该目录内还残留本次编译产生的 `*.o` 等产物（约 89 MB）。因已不参与构建，未清理；需要清理请告知。

---

## 四、遗留提醒

- **已烧录/已生成的镜像仍是“启用 WiFi”版本**：`Kernel/boot.img`、`rockchip/output/Image/boot.img`、`rockchip/output/update/Image/update.img` 都是本次改动后构建的，**未回退**（本次仅回退源码/配置）。★
- 内核 `.config` 仍保留上次生成的 `CONFIG_RTL8723DS=y`；下次执行 `make rockchip_linux_defconfig` 会按已回退的 defconfig 重新生成。◎

---

## 五、当前状态一览

| 项 | 状态 |
|----|------|
| 源码/配置 | 已恢复改动前（除 v5.10 驱动源码不可还原外） |
| `rtl8723ds/` 目录 | 保留 v5.13.5，未接入构建（inert） |
| 备份 `sdio_wifi` | 已生成于 `模块/Linux/RTL8723DS/sdio_wifi/` |
| boot.img / update.img | 仍旧（启用 WiFi 版），未重建 |

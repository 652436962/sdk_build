# RTL8723DS（SDIO WiFi）集成说明

> 平台：RK3562 / TL3562-EVM-SDIO-WIFI，Ubuntu 20.04，内核 `5.10.209`
> 驱动：Realtek RTL8723DS WiFi Linux **v5.13.5-91**（仅 WiFi，不含 BT）
> 目录用途：RK3562 SDK 上 RTL8723DS SDIO WiFi 的集成资料、脚本与备份

## 一、文件索引

| 文件/目录 | 说明 |
|-----------|------|
| `RTL8723DS_v5.13.5_集成计划.md` | 集成方案与改动计划 |
| `RTL8723DS_v5.13.5_改动明细.md` | 逐条改动明细（含编译验证） |
| `RTL8723DS_v5.13.5_实机检查记录.md` | 烧录后实机检查记录 |
| `RTL8723DS_v5.13.5_回退与备份记录.md` | 备份与回退记录 |
| `RTL8723DS_SDIO检测命令.md` | 串口/SDIO 检测命令与判定表 |
| `RTL8723DS_WiFi_linux_v5.13.5-91.../` | 原厂驱动包（WiFi + BT 两份 tar.gz） |
| `sdio_wifi/` | 集成改动备份（`changed/` 文件 + 驱动源码 tar） |
| `ap/` | AP 模式脚本 `wifi_ap.sh` 与 `hostapd.conf` |

## 二、硬件连接（本板）

| 项 | 值 |
|----|----|
| 模组总线 | **`sdmmc0`（TF 卡槽总线，`mmc1`，`ff880000`）** |
| 供电 | **默认上电**（`vmmc=vcc3v3_sd` / `vqmmc=vccio_sd`），非 GPIO 控制 |
| 属性 | 常驻（`non-removable`） |
| **TF 卡检测脚** | **`gpio0-4` 必须为低**（硬件接地），否则 4-bit 下模组不工作 |

> 注意：本板 RTL8723DS 走的是 **TF 卡 SDIO**，不是原厂 `tl3562-evm-sdio-wifi.dts` 里的 `sdmmc1`。

## 三、设备树关键配置（`tl3562-evm-sdio-wifi.dts`）

```dts
&sdmmc0 {
	/delete-property/ no-sdio;      /* 允许 SDIO */
	/delete-property/ sd-uhs-sdr104;
	no-sd;
	bus-width = <4>;
	cap-sdio-irq;
	keep-power-in-suspend;
	non-removable;
	max-frequency = <1000000>;      /* 视实测调整 */
	status = "okay";
};

&sdmmc1 { status = "disabled"; };   /* 原厂 SDIO WiFi 控制器未用 */
```

内核侧：`CONFIG_RTL8723DS=y`、`# CONFIG_RTL8189FS is not set`。

## 四、实测结论（重要）

1. **4-bit 失败、1-bit 成功**（同固件、分别 `bus-width=<4>` / `<1>`）：
   - 4-bit 时：`RTW: sdio_power_on_check ... cmd52 and cmd53 is not the same` → `sd_write32 (-110) addr=0x11000` → 固件下载失败 → `rtw_init_primary_adapter Failed` → **无 wlan0**。
   - 该现象在 **25MHz / 12.5MHz / 1MHz** 三个时钟下**完全一致**，与时钟无关。
2. **根因是 TF 检测脚**：把 `gpio0-4`（TF 卡检测脚）**接地拉低后，`ifconfig` 能识别到设备**（用户实测）。
3. 因此硬件侧需保证 **TF 检测脚为低**；软件侧可用 `non-removable`（本方案）或对 `gpio0-4` 做拉低处理。

## 五、AP 模式脚本（`ap/wifi_ap.sh`）

板卡路径：`/lechi/wifi_ap.sh`（用法 `wifi_ap.sh {start|stop|restart}`）

- 默认参数：`wlan0`、SSID `test`、密码 `test123456`、信道 6、IP `172.31.100.1`、掩码 `255.255.0.0`
- 动作：写 `/etc/hostapd/hostapd.conf` → 拉起 `wlan0` 并配 IP → 启动 `hostapd`
- 实测输出：

```
Interface wlan0
	type AP
	ssid test
	channel 6 (2437 MHz), width: 20 MHz
wlan0  UP  172.31.100.1/16
```

- 前置条件：`hostapd`、`iw`、`ifconfig` 已存在（Ubuntu rootfs 自带）。

```sh
/lechi/wifi_ap.sh start     # 开启 AP
/lechi/wifi_ap.sh stop      # 关闭 AP
/lechi/wifi_ap.sh restart   # 重启 AP
```

## 六、待办 / 未覆盖

- **4-bit 全速可用性**：需先确保 TF 检测脚为低，再验证 4-bit（此前测试均在检测脚未拉低时进行）。
- **DHCP**：AP 未启用 DHCP 服务器，客户端需手动配同网段 IP（如需可用 `dnsmasq` 分配 `172.31.0.0/16`）。
- **开机自启**：`hostapd` 目前为手动/脚本启动，未做 systemd 服务。
- **BT**：本目录仅 WiFi；BT 驱动见原厂包 `BT/20210416_BT_..._v3b3b.tar.gz`。

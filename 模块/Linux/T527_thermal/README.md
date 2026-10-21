# T527（飞凌 OKT527-C）温度误关机 —— 排障入口文档

> **结论（2026-09-16，已上板取证）**：`reboot: Power down` **不是真实过热、不是芯片/板卡损坏**，
> 而是 **THS 温度读数在"负载/电源域动作"瞬间被毫秒级扰动**（原始码 ~2050 → 650~750，按官方公式算出 130~141 ℃），
> 叠加 **驱动缺少异常值剔除（去毛刺）**，于是 `critical` 误触发 → `hw_protection_shutdown()` → 主动关机。
> 真实工作温度只有 45~70 ℃（两簇最高频稳态 47~52 ℃）。
>
> **完整证据链、根因分析、修复方案见 → [T527温度误关机分析报告.md](./T527温度误关机分析报告.md)**

---

## 一、文档与产物索引

| 文件 | 说明 |
|---|---|
| [T527温度误关机分析报告.md](./T527温度误关机分析报告.md) | **主报告**：现象 / 证据链 / 根因 / 修复建议 / 附录（寄存器、公式、命令、时间线） |
| `scripts/S00thslog` | 开机分段采样脚本（前 12 s 全速 ~15 Hz 抓异常，之后 1 次/秒做基线） |
| `scripts/ths-watch.sh` | 运行时巡检（6 温区 + ths1 原始码 + 校准寄存器 + GPADC CH3 + 各 policy 频率） |
| `scripts/analyze-capture.sh` | 本地分析抓取文件（按启动切段、给极值、标出"被关机的那一段"） |
| `captures/` | 抓取归档（`ths-boot-20260916-175557.log` 含**误触发前 3 行决定性证据**） |

## 二、关机链路（速记）

```
温区采样值 >= critical trip（cpul_thermal_zone）
  → drivers/thermal/thermal_core.c:327  thermal_zone_device_critical()
  → hw_protection_shutdown("Temperature too high", 100ms)
  → kernel/reboot.c:530 超时后 kernel_power_off() → printk "reboot: Power down"
```

温区对应：zone0=cpul(ch1) / zone1=cpub(ch0) / zone2=gpu(用 ch3 数据) / zone3=npu(ch3) /
zone4=ddr(ths0，本板不可信) / zone5=axp2202 PMU。

## 三、脚本用法

### 3.1 部署（板子上操作，无需重编镜像；rootfs 已 rw）

```sh
# 本机上传（板子重烧后先 ssh-keygen -R 192.168.1.232）
scp scripts/S00thslog scripts/ths-watch.sh root@192.168.1.232:/root/
# 板子上安装为开机第一个脚本（rcS 约 8.2 s 起跑，赶在异常窗口 8.6 s 之前）
ssh root@192.168.1.232 'cp /root/S00thslog /etc/init.d/S00thslog && chmod 755 /etc/init.d/S00thslog'
```

### 3.2 抓取一次开机现场

```sh
ssh root@192.168.1.232 'rm -f /root/ths-boot.log; sync; reboot'
sleep 60
scp root@192.168.1.232:/root/ths-boot.log captures/
bash scripts/analyze-capture.sh captures/ths-boot-*.log
```

环境变量（也可 `THSLOG_SEC=60 sh /root/S00thslog` 手动跑）：

| 变量 | 默认 | 说明 |
|---|---|---|
| `THSLOG_SEC` | 300 | 总采样时长秒；0=不启用 |
| `FAST_SEC` | 12 | 全速段秒数（含原始码/GPADC），之后降为 1 次/秒 |
| `THSLOG` | `/root/ths-boot.log` | 采样文件（追加写；留空=只打串口） |
| `NTC` | 1 | 0=不读 GPADC CH3 |

### 3.3 巡检与满载对照

```sh
ssh root@192.168.1.232 'sh /root/ths-watch.sh base 10'          # 稳态基线
ssh root@192.168.1.232 'for i in 1 2 3 4 5 6 7 8; do (while :; do :; done) & done; sleep 20; kill $(jobs -p)'  # 满载（大概率触发误关机！）
```

## 四、判读规则（速查）

换算（`sun55iw3_calc_temp()`，℃）与常用对照：

```
code >  1991 : T = (2736 - code) * 0.074     ← 55 ℃ 以下
code <= 1991 : T = (2825 - code) * 0.065     ← 54 ℃ 以上（高温走这支）
```

| 码 | 2101 | 2050 | 2000 | 1900 | 1800 | 1700 | 1600 | 1500 | 1400 | 1300 | 1200 | 1100 | 1000 | 900 | 825 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ℃ | 47.1 | 50.8 | 54.5 | 60.1 | 66.6 | 73.1 | 79.6 | 86.1 | 92.6 | 99.1 | 105.6 | 112.1 | 118.6 | 125.1 | **130** |

寄存器速查：

| 地址 | 用途 |
|---|---|
| `0x020094C0` / `0x020094C4` | cpub(ch0) / cpul(ch1) 原始码 |
| `0x02009420` | DATA_INTS 数据有效状态 |
| `0x020094A0` / `0x020094A4` | 校准 cdata（默认 0x800；实测 0x083C0841 / 0x0845083C = 已校准） |
| `0x0200A0C0` / `0x0200A0A0` | ddr(ths0) 原始码 / 校准（本板该通道不可信） |

判读：

* **假读数（本次结论）**：单/多通道原始码毫秒级骤降、其它通道与 PMU 温区不同步、或同一秒内 sysfs 与直读寄存器互相矛盾；
* **真实升温**：多通道同步、连续数秒缓变、随负载回落，速率量级 ≤10 ℃/s（实测最快 ~7.5 ℃/s）。

## 五、记录模板（每次实验填一行）

| 日期时间 | 镜像/DTB | 启动序号 | 是否关机(时刻) | z0 cpul | z1 cpub | z4 ddr | z5 PMU | raw_c1 | NTC(mV/℃) | SoC 表面实测 | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2026-09-16 17:0x | 15:14/crit130 | 1 | 否 | 47064 | 47064 | -18722 | 41000 | 2100 | 1173 / 67.3 | 待测 | 两簇 1416/1800 MHz |
| 2026-09-16 17:49 | 15:14/crit130 | 1 | **是**(~8.6 s) | 101465 | 118755 | 67730 | 44500 | 739 | — | — | 抓取证据，见报告 2.5 |
| 2026-09-16 18:02 | 15:14/crit130 | — | **是**(8 核满载) | 73905 | 72020 | — | 42100 | 717(直读) | — | — | 复现，见报告 2.6 |
|  |  |  |  |  |  |  |  |  |  |  |  |

## 六、待办与回退清单

- [ ] **板子当前处于热保护断电状态**（2026-09-16 18:02 满载复现时被关机），需**手动重新上电**。
- [ ] 重新上电后把最新版分段采样脚本重新下发（板上目前仍是旧版 `THSLOG_SEC=300`、无 `FAST_SEC` 分段）：
      `scp scripts/S00thslog root@192.168.1.232:/root/ && ssh root@192.168.1.232 'cp /root/S00thslog /etc/init.d/S00thslog'`；
      并取回板上累积的 `/root/ths-boot.log`（含上一轮约 300 s 基线）到 `captures/`。
- [ ] **回退临时诊断**：`OKT527-C-Common.dtsi` 末尾 `&cpul_crit/&cpub_crit/&gpu_crit = <130000>` 是临时值，
      修复后恢复板级 115 ℃（`FET527.dtsi:912`；die 级基础值 110 ℃）。
- [ ] **驱动去毛刺补丁（待确认后实施）**：`sunxi_ths_get_temp()` 增加"单次突变 >30 ℃ 先不采信、
      连续 2 次一致才接受"（设计见报告 5.1）。**这是本问题的正解；继续抬高 critical 无效**
      （扰动峰值 136~141 ℃）。
- [ ] **数据手册对照实验（可选、成本低）**：① `sun55iw3_thermal_init()` 里 `PC_TEMP_PERIOD(28)` 改回手册默认
      `58`（10 ms）；② `FILTER_TYPE` 由 1（4 点平均）改 3（16 点平均）；③ 启用硬件告警中断（`0x40~0x4C`，
      默认阈值约 90 ℃）统计扰动频次。手册依据见报告 2.8。
- [ ] 注意：Datasheet Table 7-2 规定 **Tj 正常 ≤115 ℃、破坏性 125 ℃**，因此临时抬到 130 ℃ 的 critical
      不仅无效（扰动峰值 136~141 ℃）而且已超破坏性温度，**必须回退**。
- [ ] **IO/模拟域排查（手册依据见报告 2.9）**：THS 无对外引脚，只可能通过①模拟参考网络
      （VCC-ADC W7 / VCM-ADC Y9 / VREFN-ADC Y10）②GPADC0~23、LRADC0~1（本板 GPADC0 的 CH3/4/6 与 GPADC1 CH0~8、
      LRADC 6 键均在活动）③共用 24M 时钟（CLK_GPADC1_24M＝THS1 sclk）④板级大电流 IO 间接耦合。
      实验：逐个关外设做 8 核满载对照；停掉 CH3 采样脚本再满载；示波器量 VCC-ADC/VCM-ADC 纹波（空载 vs 满载）。
- [ ] 核对 `bank[G]/bank[M] power mode not correct, power_val=1800000, power_sel=3300000`（PG0/LEDC、PG10~14/I2S1、PM0/1）。
- [ ] 向飞凌/全志确认：THS 采样时钟/模拟供电在 GPU/NPU/摄像头电源域上电、满载电流突变时是否被扰动；
      是否有 errata 或官方补丁；ths0（DDR）通道乱跳是否已知。
- [ ] `ddr_thermal_zone` 读数不可用（-12~+44 ℃ 乱跳）：DTS 移除或驱动屏蔽。
- [ ] GPADC CH3（板级温度，位于 SoC/核心板附近）需按 `模块/OpenHarmony/opT527_gpadc.md`
      复核采样率/settling/通道配置后，才能当绝对温度基准。
- [ ] 修复后按报告第 6 节验证：多次启动 + 满载不再误关机，且人为加热/`emul_temp` 仍能触发保护。

## 七、代码与文件位置

| 用途 | 路径 |
|---|---|
| 板级设备树 | `t527_sdk/OKT527-linux-sdk/kernel/linux-5.15/arch/arm64/boot/dts/allwinner/OKT527-C-Common.dtsi` |
| SoC 温区/OPP | `t527_sdk/OKT527-linux-sdk/bsp/configs/linux-5.15/sun55iw3p1.dtsi` |
| ths 驱动 | `t527_sdk/OKT527-linux-sdk/bsp/drivers/thermal/sunxi_thermal.c`（+ `sunxi_thermal.h`） |
| 内核生效配置 | `t527_sdk/OKT527-linux-sdk/out/t527/kernel/staging/.config` |
| 重编内核 + 打包 | 容器 `t527_linuxsdk` 内 `cd /workspace/OKT527-linux-sdk && ./build.sh kernel && ./build.sh pack` |

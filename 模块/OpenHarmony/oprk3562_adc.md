# RK3562 电压+电流+温度 IIO ADC 采集（飞凌 OK3562-C）

**芯片型号**：RK3562 (Rockchip)  
**适配平台**：RK3562 Linux (buildroot + kernel)  
**内核版本**：Linux 5.10  
**采集接口**：IIO (Industrial I/O) subsystem，sysfs 用户态读取  

---

## 一、内核配置

**文件**：`Kernel/arch/arm64/configs/rk3562_linux_dictpen_defconfig`

```ini
CONFIG_ROCKCHIP_SARADC=y
CONFIG_IIO=y
```

> RK3562 的 SARADC 通过 IIO 框架暴露到 sysfs，无需额外驱动。

---

## 二、设备树配置

**文件**：`Kernel/arch/arm64/boot/dts/rockchip/rk3562.dtsi`（SoC 级）  
**文件**：`Kernel/arch/arm64/boot/dts/rockchip/rk3562-xxx.dts`（板级）

```dts
&saradc {
	status = "okay";
	vref-supply = <&vcc_1v8>;
};
```

---

## 三、sysfs 接口说明

| 路径 | 说明 |
| ---- | ---- |
| `/sys/bus/iio/devices/iio:device1/in_voltage_scale` | ADC 量程比例系数 (mV) |
| `/sys/bus/iio/devices/iio:device1/in_voltage0_raw` | IN0 原始值（电压采集） |
| `/sys/bus/iio/devices/iio:device1/in_voltage1_raw` | IN1 原始值（温度采集） |
| `/sys/bus/iio/devices/iio:device1/in_voltage2_raw` | IN2 原始值（电流采集） |

> `iio:device1` 为 rk3562-evb1-lp4x-v10-linux.dts 板的默认设备号，实际可能为 `iio:device0`，以 `/sys/bus/iio/devices/` 下实际为准。

---

## 四、计算公式

### 4.1 电压

```
Vadc = raw × scale  (mV)
Vin  = Vadc × KV / 1000  (V)

KV = (R1 + R2) / R2 = (732 + 100) / 100 = 8.32
```

### 4.2 电流

```
Iadc = raw × scale  (mV)
I    = Iadc / RS / GAIN  (A)

RS = 50 mΩ（采样电阻）
GAIN = 50（放大器增益）
```

### 4.3 温度（分段线性）

| 区间 | VOFFS (mV) | TC (mV/℃) | TINFL (℃) |
| ---- | ---------- | ---------- | --------- |
| Tadc ≤ 2350 | 400 | 19.5 | 0 |
| Tadc > 2350 | 2350 | 19.7 | 100 |

```
Temp = (Tadc - VOFFS) / TC + TINFL  (℃)
```

---

## 五、采集脚本

```bash
#!/bin/bash
echo "=== RK3562 电压+电流+温度实时采集 (Ctrl+C 退出) ==="
KV=8.32
RS=50.0
GAIN=50.0

while true; do
	scale=$(cat /sys/bus/iio/devices/iio:device1/in_voltage_scale)

	# 电压 IN0
	raw_vol=$(cat /sys/bus/iio/devices/iio:device1/in_voltage0_raw)
	Vadc=$(echo "scale=6;$raw_vol*$scale" | bc)
	Vin=$(echo "scale=4;$Vadc*$KV/1000" | bc)

	# 电流 IN2
	raw_cur=$(cat /sys/bus/iio/devices/iio:device1/in_voltage2_raw)
	Iadc=$(echo "scale=6;$raw_cur*$scale" | bc)
	I=$(echo "scale=4;$Iadc/$RS/$GAIN" | bc)

	# 温度 IN1
	raw_tmp=$(cat /sys/bus/iio/devices/iio:device1/in_voltage1_raw)
	Tadc=$(echo "scale=2;$raw_tmp*$scale" | bc)
	VOFFS=0; TC=0; TINFL=0
	if (( $(echo "$Tadc <= 2350.0" | bc -l) )); then
		TINFL=0.0; TC=19.5; VOFFS=400.0
	else
		TINFL=100.0; TC=19.7; VOFFS=2350.0
	fi
	Temp=$(echo "scale=1;($Tadc-$VOFFS)/$TC+$TINFL" | bc)

	echo "====================================="
	echo "ADC_scale: ${scale}"
	echo "电源电压: ${Vin} V"
	echo "回路电流: ${I} A"
	echo "主板温度: ${Temp} ℃"
	sleep 1
done
```

---

## 六、验证

```bash
# 1. 确认 IIO 设备存在
ls /sys/bus/iio/devices/

# 2. 确认 scale 可读
cat /sys/bus/iio/devices/iio:device1/in_voltage_scale

# 3. 读取原始值
cat /sys/bus/iio/devices/iio:device1/in_voltage0_raw
cat /sys/bus/iio/devices/iio:device1/in_voltage1_raw
cat /sys/bus/iio/devices/iio:device1/in_voltage2_raw

# 4. 运行采集脚本
./adc_collect.sh
```

---

## 七、常见问题

### 问题一：`/sys/bus/iio/devices/` 下无设备

- **原因一**：SARADC 驱动未加载或设备树未使能
- **解决**：检查 `CONFIG_ROCKCHIP_SARADC=y` 及设备树 `&saradc { status = "okay"; }`

- **原因二**：设备号不是 `iio:device1`
- **解决**：`ls /sys/bus/iio/devices/` 确认实际设备号，脚本中对应修改

### 问题二：采集值全为 0 或无变化

- **原因**：ADC 通道未连接信号源
- **解决**：检查硬件接线，确认 SARADC 对应管脚有电压输入

### 问题三：`bc` 命令不存在

- **原因**：buildroot 未安装 bc
- **解决**：在 buildroot menuconfig 中启用 `BR2_PACKAGE_BC`，或使用 awk 替代计算

### 问题四：scale 值读取异常

- **原因**：参考电压 vref-supply 配置错误
- **解决**：确认设备树中 `vref-supply = <&vcc_1v8>` 与实际硬件一致（1.8V）

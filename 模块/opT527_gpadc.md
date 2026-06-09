# T527 OpenHarmony 5.0 GPADC 电压采集（飞凌 OKT527-C）

**芯片型号**：Allwinner T527  
**适配平台**：T527 OpenHarmony 5.0  
**内核版本**：Linux 5.10  
**采集接口**：GPADC sysfs，`/sys/class/gpadc/gpadc_chip0/`  
**参考文档**：[全志 GPADC 文档](https://docs.aw-ol.com/docs/soc/v821/system/gpadc/)

---

## 一、内核配置

**文件**：`device/soc/allwinner/t527/patches/config/t527_standard_defconfig`

```ini
CONFIG_AW_BSP=y
CONFIG_AW_GPADC=y
```

> `CONFIG_AW_GPADC` 依赖 `CONFIG_AW_BSP`（Allwinner BSP），两者必须同时开启。  
> 驱动源码位于 `device/board/forlinx/okt527/kernel/driver/drivers/gpadc/sunxi_gpadc.c`，编译为 `sunxi_gpadc.o`。

---

## 二、设备树配置

### 2.1 文件路径

| 层级 | 文件 |
| ---- | ---- |
| SoC 级 dtsi（默认配置） | `device/board/forlinx/okt527/bootloader/configs/default/linux-5.10/sun55iw3p1.dtsi` |
| 板级 dts（用户修改） | `device/board/forlinx/okt527/bootloader/configs/okt527/linux-5.10/board.dts` |

### 2.2 ADC 模式配置（采集电压，非按键）

```dts
&gpadc0 {
	channel_num = <7>;              /* 必须 ≥ 最高通道号+1，当前配置 CH3/4/6 需 ≥7 */
	channel_select = <0x58>;        /* 0x58 = 0b01011000，使能 CH3(CH4)CH6 */
	channel_data_select = <0x58>;   /* 数据 IRQ 通道，与 channel_select 保持一致 */
	channel_compare_select = <0>;   /* 纯 ADC 模式下关闭比较功能 */
	channel_cld_select = <0>;
	channel_chd_select = <0>;
	status = "okay";
};
```

### 2.3 关键参数说明

| 参数 | 说明 | 示例 |
| ---- | ---- | ---- |
| `channel_num` | 必须 ≥ 最高通道号 + 1。驱动用 `for(i=0; i<channel_num; i++)` 遍历，若 `channel_num=3` 则只遍历 CH0~2，CH3/4/6 无法使能 | `0x58` 选 CH3/4/6 则设为 `<7>` |
| `channel_select` | 位掩码使能通道，bit0=CH0, bit1=CH1... | `0x58` = 0b01011000 → CH3, CH4, CH6 |
| `channel_data_select` | 数据中断通道，ADC 模式与 channel_select 相同 | |
| `channel_compare/cld/chd_select` | ADC 模式下全部设为 0 | |
| `status` | SoC 级 dtsi 中默认可为 `"okay"`，但板级 dts 会覆盖，务必检查 | |

### 2.4 ADC 模式 vs 按键模式

| 对比项 | ADC 模式 | 按键模式 |
| ------ | -------- | -------- |
| channel_data_select | 与 channel_select 相同 | 设为 0（不触发数据中断） |
| channel_cld/chd_select | 0 | 阈值比较通道掩码 |
| keyadc 子节点 | 不需要 | 需要 keyadcX 子节点配置按键电压 |
| 数据上报 | input 事件 EV_MSC / MSC_SCAN | input 事件 EV_KEY |
| 电压读取 | `cat /sys/class/gpadc/gpadc_chip0/data` | `cat /dev/input/eventX` |

---

## 三、编译

```bash
# 1. 进入容器
docker start t527_openharmony
docker exec -it t527_openharmony /bin/bash

# 2. 提交修改（构建会 clone 新代码，不 commit 会丢失）
# 注意：kernel/ 和 device/board/ 均在主仓库内，直接 git add 即可
cd /home/openharmony/forlinx-5.0-release
git add device/soc/allwinner/t527/patches/config/t527_standard_defconfig
git add device/board/forlinx/okt527/bootloader/configs/okt527/linux-5.10/board.dts
git commit -m "feat: enable GPADC0 for voltage sampling (CH3/CH4/CH6)"

# 3. 编译
./build.sh --product-name okt527 --ccache
```

---

## 四、sysfs 读取电压

### 4.1 设备节点

编译烧写后，GPADC sysfs 节点位于：

```
/sys/class/gpadc/gpadc_chip0/
```

`gpadc_chip0` 对应 GPADC0 控制器（即 `gpadc0@2009000`）。

### 4.2 读取各通道电压

```bash
# CH3 → 温度采集
echo 3 > /sys/class/gpadc/gpadc_chip0/data && cat /sys/class/gpadc/gpadc_chip0/data

# CH4 → 电压采集
echo 4 > /sys/class/gpadc/gpadc_chip0/data && cat /sys/class/gpadc/gpadc_chip0/data

# CH6 → 电流采集
echo 6 > /sys/class/gpadc/gpadc_chip0/data && cat /sys/class/gpadc/gpadc_chip0/data
```

> `cat data` 返回的值**单位是毫伏 (mV)**  
> 读取前必须先 `echo N > data` 切换到目标通道。

### 4.3 其他 sysfs 节点

| 节点 | 读写 | 说明 |
| ---- | ---- | ---- |
| `status` | R/W | 通道开关，`cat status` 查看，`echo gpadc0,1 > status` 开启 |
| `sr` | R/W | 采样率，范围 400~100000 Hz，如 `echo 5000 > sr` |
| `filter` | R/W | 滤波阈值，如 `echo 6 > filter` |
| `data` | R/W | 写通道号切换，读获取当前通道电压 (mV) |

---

## 五、电压换算

### 5.1 电压

```
Vadc = 测量值 (mV)                    ← cat data 的返回值即 GPADC 管脚电压
Vin  = Vadc × KV / 1000  (V)
     = 测量值 × 8.32 / 1000  (V)
     = 测量值 × 8.32  (mV)

KV = (R1 + R2) / R2 = (732 + 100) / 100 = 8.32
```

> 分压电阻：R1 = 732kΩ（上拉），R2 = 100kΩ（下拉），参考电压 1.8V。  
> 被测电压范围：0 ~ 14.976V（1.8V × 8.32）。

### 5.2 电流

```
Iadc = 测量值 (mV)                    ← cat data 的返回值
I    = Iadc / RS / GAIN  (A)
     = 测量值 / 5  (mA)
     = 测量值 / 5000  (A)

RS = 50 mΩ（采样电阻）
GAIN = 100（放大器增益）
```

### 5.3 温度

```
Tadc = 测量值 (mV)                    ← cat data 的返回值
Temp = (Tadc - 500) / 10  (℃)
```

> T527 平台下 NTC 温度传感器线性校准公式。500(mV) 为零点偏移，10(mV/℃) 为比例系数。

---

## 六、采集脚本

```bash
#!/bin/bash
echo "=== T527 GPADC 电压+电流+温度实时采集 (Ctrl+C 退出) ==="

GPADC_PATH="/sys/class/gpadc/gpadc_chip0/data"
KV=8.32
RS=0.05
GAIN=100.0

while true; do
	# 电压 CH4
	echo 4 > ${GPADC_PATH}
	raw_vol=$(cat ${GPADC_PATH})
	Vadc=$(echo "scale=2;${raw_vol}" | bc)
	Vin=$(echo "scale=4;${Vadc}*${KV}/1000" | bc)

	# 电流 CH6
	echo 6 > ${GPADC_PATH}
	raw_cur=$(cat ${GPADC_PATH})
	Iadc=$(echo "scale=2;${raw_cur}" | bc)
	I=$(echo "scale=4;${Iadc}/${RS}/${GAIN}" | bc)

	# 温度 CH3
	echo 3 > ${GPADC_PATH}
	raw_tmp=$(cat ${GPADC_PATH})
	Tadc=$(echo "scale=2;${raw_tmp}" | bc)
	Temp=$(echo "scale=1;(${Tadc}-500)/10" | bc)

	echo "====================================="
	printf "电源电压: %.4f V\n" ${Vin}
	printf "回路电流: %.4f A  (%.2f mA)\n" ${I} $(echo "${I}*1000" | bc)
	printf "主板温度: %.1f ℃\n" ${Temp}
	sleep 1
done
```

---

## 七、验证





---

## 八、常见问题

### 问题一：`/sys/class/gpadc/` 为空

- **原因一**：`CONFIG_AW_GPADC` 未开启或 `CONFIG_AW_BSP` 未开启
- **解决**：确认 `t527_standard_defconfig` 中 `CONFIG_AW_BSP=y` 和 `CONFIG_AW_GPADC=y`

- **原因二**：设备树 `status = "disabled"`
- **解决**：检查板级 `board.dts` 中 `&gpadc0 { status = "okay"; }`

- **原因三**：编译后未 commit，构建 clone 了旧代码
- **解决**：在容器内 `git add` + `git commit` 后再 `./build.sh`

### 问题二：所有通道读取值均为 1800001

- **原因**：通道未使能，驱动返回 `VOL_REFER + 1 = 1800001`（无效标记）
- **解决**：确认 `channel_num` ≥ 最高通道号 + 1。例如 `channel_select = <0x58>` (CH3/4/6) 则 `channel_num` 至少为 `<7>`

### 问题三：读取值为 0 或无变化

- **原因**：ADC 输入引脚未连接或浮空
- **解决**：用万用表测量对应管脚电压，或用分压电阻接入已知电压验证

### 问题四：`status` 设为 `okay` 但仍不工作

- **原因**：SoC 级 `sun55iw3p1.dtsi` 中 `gpadc0` 默认为 `okay`，但板级 `board.dts` 的 `&gpadc0` 引用会覆盖属性
- **解决**：在 `board.dts` 的 `&gpadc0 { ... }` 块内正确配置所有参数

### 问题五：`bc` 命令不存在

- **原因**：OpenHarmony 环境可能未安装 bc
- **解决**：安装 `bc` 或使用 awk/expr 替代计算；简单读取可直接用 `cat data` 查看 mV 值

---

## 九、相关文件路径

| 文件 | 路径 |
| ---- | ---- |
| 内核配置 defconfig | `device/soc/allwinner/t527/patches/config/t527_standard_defconfig` |
| SoC 级 dtsi | `device/board/forlinx/okt527/bootloader/configs/default/linux-5.10/sun55iw3p1.dtsi` |
| 板级 dts | `device/board/forlinx/okt527/bootloader/configs/okt527/linux-5.10/board.dts` |
| GPADC 驱动源码 | `device/board/forlinx/okt527/kernel/driver/drivers/gpadc/sunxi_gpadc.c` |
| GPADC Kconfig | `device/board/forlinx/okt527/kernel/driver/drivers/gpadc/Kconfig` |
| sysfs 节点 | `/sys/class/gpadc/gpadc_chip0/data` |

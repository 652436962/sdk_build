# 全志 T113i SPI1 引脚配置 (接 ADC)

<!--
  功能: SPI1 引脚复用与驱动强度配置，用于外接 SPI ADC 采集芯片
  日期: 2025-03-27
  作者: fanhui
  修改: PB9 (miso) → PD13 (miso)，解决原 PB9 引脚冲突
-->

/*
 * SPI1 引脚配置节点
 * 用于连接外部 SPI ADC 芯片（如 MCP3008/ADS7953 等），
 * 通过 SPI 总线读取多路模拟量。
 */
spi1_pins_a: spi1@0 {
	/*
	 * SPI 四线引脚分配:
	 *   PB11 — CLK  (时钟)
	 *   PB10 — MOSI (主出从入)
	 *   PD13 — MISO (主入从出) [原 PB9，因冲突改为 PD13]
	 *   HOLD — 未引出，由片内保持
	 *   WP   — 未引出，由片内写保护
	 */
	pins = "PB11", "PB10", "PD13";  /* clk, mosi, miso */

	/* 引脚功能: 复用为 SPI1 控制器 */
	function = "spi1";

	/* 驱动强度: 10mA，适用于标准 SPI 速率 */
	drive-strength = <10>;

	/* 下拉偏置: 空闲时将引脚拉低，防止浮空抖动 */
	bias-pull-down;
};
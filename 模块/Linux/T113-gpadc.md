# 全志 T113i GPADC 采集配置

<!--
  功能: GPADC (General Purpose ADC) 设备树配置
  日期: 2025-12-24 18:50:45
  作者: fanhui
  说明: 启用 GPADC 模块，配置双通道轮询采集
-->

/*
 * GPADC 控制器节点
 * 全志 T113i 的 GPADC 支持最多 2 路模拟输入通道，
 * 通过轮询方式分时采集各通道数据。
 */
&gpadc {
	/* 通道数量: 2 个采集通道 (CH0, CH1) */
	channel_num = <2>;

	/*
	 * 通道选择位掩码 (0x3 = 0b0011)
	 * bit0: CH0 使能
	 * bit1: CH1 使能
	 * 当前同时使能 CH0 和 CH1
	 */
	channel_select = <0x3>;

	/*
	 * 通道数据选择位掩码 (0x3 = 0b0011)
	 * bit0: CH0 数据有效
	 * bit1: CH1 数据有效
	 * 与 channel_select 保持一致，采集对应通道数据
	 */
	channel_data_select = <0x3>;

	/* 通道比较选择: 0 表示不使用比较功能 */
	channel_compare_select = <0>;

	/* 通道 CLD (低阈值检测) 选择: 0 表示不启用 */
	channel_cld_select = <0>;

	/* 通道 CHD (高阈值检测) 选择: 0 表示不启用 */
	channel_chd_select = <0>;

	/* 节点状态: okay 表示启用此设备 */
	status = "okay";
};

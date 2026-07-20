# 全志 T113i GPADC 采集配置

## 概述

启用 T113i GPADC 模块，配置双通道（CH0/CH1）轮询采集模拟量。

## 设备树配置

| 配置文件 | 适用内核 | 描述 |
|----------|----------|------|
| `0001-t113-gpadc.dts` | T113i | 使能 GPADC，双通道轮询，关闭比较/阈值检测 |

```bash
# 将节点内容复制到对应设备树中
```

源码见 [0001-t113-gpadc.dts](0001-t113-gpadc.dts)。

## 配置说明

| 属性 | 值 | 说明 |
|------|-----|------|
| channel_num | 2 | 采集通道数 |
| channel_select | 0x3 | CH0+CH1 使能 |
| channel_data_select | 0x3 | CH0+CH1 数据有效 |
| channel_compare_select | 0 | 关闭比较功能 |
| channel_cld_select | 0 | 关闭低阈值检测 |
| channel_chd_select | 0 | 关闭高阈值检测 |

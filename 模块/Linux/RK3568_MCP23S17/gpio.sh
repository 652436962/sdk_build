#!/bin/bash

# 检查参数是否正确
if [ $# -ne 2 ]; then
    echo "用法: $0 <引脚号> <电平值(0|1)>"
    echo "示例: $0 101 1  # 设置GPIO101为高电平"
    exit 1
fi

GPIO=$1
VALUE=$2

# 检查电平值是否合法
if [ "$VALUE" != "0" ] && [ "$VALUE" != "1" ]; then
    echo "错误: 电平值必须是0或1"
    exit 1
fi

# 检查GPIO是否已导出，若已导出则先释放
if [ -d "/sys/class/gpio/gpio$GPIO" ]; then
    echo $GPIO > /sys/class/gpio/unexport 2>/dev/null
    sleep 0.1  # 等待释放完成
fi

# 导出GPIO
echo "导出GPIO$GPIO..."
if ! echo $GPIO > /sys/class/gpio/export 2>/dev/null; then
    echo "错误: 无法导出GPIO$GPIO，可能被占用或不存在"
    exit 1
fi

# 等待sysfs节点创建
sleep 0.1
if [ ! -d "/sys/class/gpio/gpio$GPIO" ]; then
    echo "错误: GPIO$GPIO节点创建失败"
    exit 1
fi

# 设置为输出模式
echo "设置GPIO$GPIO为输出模式..."
if ! echo out > /sys/class/gpio/gpio$GPIO/direction 2>/dev/null; then
    echo "错误: 无法设置GPIO$GPIO为输出模式"
    # 清理资源
    echo $GPIO > /sys/class/gpio/unexport 2>/dev/null
    exit 1
fi

# 设置电平值
echo "设置GPIO$GPIO为$VALUE电平..."
if ! echo $VALUE > /sys/class/gpio/gpio$GPIO/value 2>/dev/null; then
    echo "错误: 无法设置GPIO$GPIO为$VALUE电平"
    # 清理资源
    echo $GPIO > /sys/class/gpio/unexport 2>/dev/null
    exit 1
fi

# 短暂延迟确保电平稳定
sleep 0.1

# 自动释放GPIO
echo "释放GPIO$GPIO..."
echo $GPIO > /sys/class/gpio/unexport 2>/dev/null

echo "操作完成"

# [野火] LubanCat-RK3562/RK3566/RK3568 系列板卡快速使用手册

> 来源：https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/index.html  
> 适用板卡：LubanCat-RK3562 / RK3566 / RK3568  
> PDF 文档：https://doc.embedfire.com/  
> 配套程序：https://gitee.com/LubanCat/lubancat_rk_code_storage  
> 视频教程：https://space.bilibili.com/356820657/channel/collectiondetail?sid=1352573  
> 官方商城：https://yehuosm.tmall.com

---

## 关于本项目

- [关于本项目](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/README.html)
- [关于野火](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/about_us.html)
- [RK3566/3568-6.1 内核镜像更新说明](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/baidu_cloud/update_history_rk356x_kernel6.1.html)
- [RK3566/3568-4.19 内核镜像更新说明](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/baidu_cloud/update_history_rk356x_kernel4.19.html)
- [RK3562 镜像更新说明](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/baidu_cloud/update_history_rk3562.html)

---

## LubanCat-RK 板卡

| 序号 | 内容 | 链接 |
|------|------|------|
| 1 | 鲁班猫（LubanCat）系列板卡简介 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/lubancat/lubancat.html) |
| 2 | LubanCat-RK3562/RK3566/RK3568 系列板卡简介 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/lubancat/lubancat.html#lubancat-rk3562-rk3566-rk3568) |
| 3 | LubanCat-Zero 系列硬件介绍 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/lubancat/lubancat-zero.html) |
| 4 | LubanCat-1 系列硬件介绍 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/lubancat/lubancat1.html) |
| 5 | LubanCat-2 系列硬件介绍 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/lubancat/lubancat2.html) |

---

## 快速开始

| 序号 | 内容 | 链接 |
|------|------|------|
| 1 | 百度网盘资源介绍 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/baidu_cloud/baidu_cloud.html) |
| 2 | 用户名及密码 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/name/name.html) |
| 3 | 系统镜像烧录 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/flash_img/flash_img.html) |
| 4 | 启动系统与系统登录 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/board_startup/board_startup.html) |
| 5 | 网络连接及静态配置 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/network/network2.html) |
| 6 | 远程桌面 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/vnc/vnc.html) |
| 7 | apt 更新软件源 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/apt/apt.html) |
| 8 | 升级包 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/updating/updating.html) |
| 9 | 查看板卡系统信息 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/system_information/system_information.html) |
| 10 | 命令行点灯和检测按键 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/led_key_command_line_testing/led_key_command_line_testing.html) |
| 11 | 文件传输与 NFS 网络文件系统 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/file_transfer/file_transfer.html) |
| 12 | 野火配置工具 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/fireconfig/fireconfig.html) |
| 13 | 配置文件 & 设备树 & 设备树插件 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/device_tree/device_tree.html) |
| 14 | GCC 编译程序 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/gcc_compile/gcc_compile.html) |

---

## 外设与接口

| 序号 | 内容 | 链接 |
|------|------|------|
| 1 | 40pin 引脚对照图 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/40pin/40pin.html) |
| 2 | GPIO 控制 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/40pin/gpio/gpio.html) |
| 3 | I2C 通讯 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/40pin/i2c/i2c.html) |
| 4 | SPI 通信 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/40pin/spi/spi.html) |
| 5 | PWM 控制 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/40pin/pwm/pwm.html) |
| 6 | 串口通讯 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/40pin/uart/uart.html) |
| 7 | CAN 总线 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/can/can.html) |
| 8 | RS485 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/rs485/rs485.html) |
| 9 | RS232 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/rs232/rs232.html) |
| 10 | 摄像头 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/camera/camera.html) |
| 11 | 屏幕与触摸 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/screen/screen.html) |
| 12 | input 子系统与触摸 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/input/input.html) |
| 13 | 风扇接口 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/fan/fan.html) |
| 14 | 红外 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/ir/ir.html) |
| 15 | 音频 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/audio/audio.html) |
| 16 | RTC | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/rtc/rtc.html) |
| 17 | 硬盘挂载 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/disk_mount/disk_mount.html) |
| 18 | MINI PCI-E 接口 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/interface/mini-pcie/mini-pcie.html) |
| 19 | WiFi | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/wireless/wifi/wifi.html) |
| 20 | Bluetooth | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/wireless/bluetooth/bluetooth.html) |
| 21 | 4G | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/wireless/4g/4g.html) |
| 22 | 5G | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/wireless/5g/5g.html) |
| 23 | GPS | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/lubancat_rk_software_hardware/hardware/gps/gps.html) |
| 24 | USB | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/interface/usb/usb.html) |
| 25 | M.2 接口 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/interface/m2/m2.html) |
| 26 | SATA 接口 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/interface/sata/sata.html) |
| 27 | ADC | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/adc/adc.html) |
| 28 | 野火扩展板 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/lubancat_rk_software_hardware/expansion_board/expansion_board.html) |
| 29 | 树莓派扩展板 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/lubancat_rk_software_hardware/expansion_board/raspberry_pi.html) |

---

## 进阶应用

| 序号 | 内容 | 链接 |
|------|------|------|
| 1 | 其他烧录方式及备份说明 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/backup/backup.html) |
| 2 | RT-Linux | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/rt-linux/rt-linux.html) |
| 3 | 视频编解码——基于 MPP 库 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/lubancat_rk_software_hardware/software/mpp/mpp.html) |
| 4 | Gstreamer 工具以及 MPP 插件 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/lubancat_rk_software_hardware/software/gstreamer/gstreamer.html) |
| 5 | 安装带硬编解码版本的 ffmpeg | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/lubancat_rk_software_hardware/software/ffmpeg/ffmpeg.html) |
| 6 | 共享键鼠神器——Synergy | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/lubancat_rk_software_hardware/software/synergy/synergy.html) |
| 7 | ISP 调试 | [链接](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/quick_start/isp/isp.html) |

---

## 常见问题

- [常见问题](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/faq/index.html)

## 版权

- [版权说明](https://doc.embedfire.com/linux/rk356x/quick_start/zh/latest/LICENSE.html)

---

© Copyright 2022, embedfire-野火 www.embedfire.com

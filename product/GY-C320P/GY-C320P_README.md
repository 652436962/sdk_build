# GY-C320P 外设测试

> **版本：** v1.0 | **更新日期：** 2026-05-26 | **适用平台：** 全志 T113

## 概述

GY-C320P 是全志 T113 采集器平台的外设综合测试文档，覆盖 GPIO 电源管理、多路串口通信、存储外设、以太网以及 4G 模块的功能验证。

---

## 1. GPIO 电源管理

通过 `power` 工具控制板载外设的 GPIO 电源通断。

### 引脚映射

| 编号 | 外设         | GPIO 引脚 | 说明             |
|------|-------------|-----------|------------------|
| 0    | RS485 接口1  | 35        | 控制 485-1 供电  |
| 1    | RS485 接口2  | 37        | 控制 485-2 供电  |
| 2    | RS485 接口3  | 137       | 控制 485-3 供电  |
| 3    | RS485 接口4  | 136       | 控制 485-4 供电  |
| 4    | PWR OUT1     | 34        | 外部供电输出1    |
| 5    | PWR OUT2     | 36        | 外部供电输出2    |
| 6    | RUN 运行灯   | user-led0 | LED 运行指示灯   |

### 使用方法

```bash
# SSH 登录目标设备
ssh root@192.168.10.50
cd /lechi

# 打开第一个口电源
./power 0 1

# 关闭第一个口电源
./power 0 0
```

---

## 2. 多串口通信测试

通过 `worker` 工具管理 5 路串口，支持数据收发与回环测试。

### 串口设备映射

| 序号 | 设备路径    | 默认参数     |
|------|-------------|-------------|
| 0    | /dev/ttyS3  | 9600-8-N-1  |
| 1    | /dev/ttyS2  | 9600-8-N-1  |
| 2    | /dev/ttyS1  | 9600-8-N-1  |
| 3    | /dev/ttyS5  | 9600-8-N-1  |
| 4    | /dev/ttyS4  | 9600-8-N-1  |

### 支持的串口参数

| 参数   | 可选值                                                    |
|--------|----------------------------------------------------------|
| 波特率 | 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200      |
| 数据位 | 6, 7, 8                                                  |
| 校验位 | N（无）, O（奇）, E（偶）, S（空格）                       |
| 停止位 | 1, 2                                                     |

### 使用方法

```bash
# SSH 登录目标设备
ssh root@192.168.10.50
cd /lechi

# 启动串口通信测试
./worker
```

> **说明：** 通过外部设备向不同串口（485/232）发送数据，在设备侧查看日志输出，验证收发是否正常。

---

## 3. TF 卡 / U 盘测试

验证存储外设的识别与挂载。

### 设备识别

| 设备节点         | 说明                       |
|-----------------|----------------------------|
| `/dev/mmcblk1p1` | TF 卡分区                  |
| `/dev/sda1`      | U 盘分区                   |

### TF 卡

```bash
root@Lechi:~# fdisk -l
Disk /dev/mmcblk1: 29 GB, 31266439168 bytes, 61067264 sectors
3801 cylinders, 255 heads, 63 sectors/track
Units: sectors of 1 * 512 = 512 bytes

Device       Boot StartCHS    EndCHS        StartLBA     EndLBA    Sectors  Size Id Type
/dev/mmcblk1p1    0,130,3     1023,254,63       8192   61067263   61059072 29.1G  c Win95 FAT32 (LBA)
```

### U 盘

```bash
root@Lechi:~# fdisk -l
Disk /dev/sda: 29 GB, 31266439168 bytes, 61067264 sectors
3801 cylinders, 255 heads, 63 sectors/track
Units: sectors of 1 * 512 = 512 bytes

Device  Boot StartCHS    EndCHS        StartLBA     EndLBA    Sectors  Size Id Type
/dev/sda1    0,130,3     1023,254,63       8192   61067263   61059072 29.1G  c Win95 FAT32 (LBA)
```

### 验证步骤

```bash
# 1. 检查设备是否识别
fdisk -l

# 2. 挂载并读写测试
mount /dev/mmcblk1p1 /mnt
ls /mnt
echo "test" > /mnt/test.txt && cat /mnt/test.txt
umount /mnt
```

> **说明：** 若 `/dev/mmcblk0` 为 eMMC 系统盘，其分区布局参考 `fdisk -l` 输出（boot-resource、env、rootfs、UDISK 等）。

---

## 4. 网口测试

验证双以太网口的连通性。

### 接口信息

| 接口 | IP 地址         | 说明     |
|------|----------------|----------|
| eth0 | 192.168.10.50  | 千兆网口 |
| eth1 | 192.168.2.100  | 百兆网口 |
| lo   | 127.0.0.1      | 本地回环 |

### 查看接口状态

```bash
root@Lechi:~# ifconfig
eth0      Link encap:Ethernet  HWaddr 26:56:A0:5F:2C:8B
          inet addr:192.168.10.50  Bcast:192.168.10.255  Mask:255.255.255.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:13 errors:0 dropped:0 overruns:0
          TX packets:17 errors:0 dropped:0 overruns:0
          Interrupt:41

eth1      Link encap:Ethernet  HWaddr 00:E0:9A:49:35:1C
          inet addr:192.168.2.100  Bcast:0.0.0.0  Mask:255.255.255.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
```

### 修改 IP 地址

若设备 IP 与主机不在同一网段，临时修改后测试：

```bash
ifconfig eth0 192.168.10.50
```

### Ping 连通性测试

```bash
# eth0 测试
root@Lechi:~# ping 192.168.10.19 -I eth0
PING 192.168.10.19: 56 data bytes
64 bytes from 192.168.10.19: seq=2 ttl=128 time=2113.908 ms
64 bytes from 192.168.10.19: seq=3 ttl=128 time=1113.780 ms
64 bytes from 192.168.10.19: seq=4 ttl=128 time=113.643 ms
64 bytes from 192.168.10.19: seq=5 ttl=128 time=0.400 ms
64 bytes from 192.168.10.19: seq=6 ttl=128 time=0.668 ms
64 bytes from 192.168.10.19: seq=7 ttl=128 time=0.383 ms

# eth1 测试（同理）
ping 192.168.2.1 -I eth1
```

---

## 5. 4G 模块测试

如果使用移远购买的EC20模块，需执行如下命令
microcom -t 15000 -s 115200 /dev/ttyUSB2 
AT+QNETDEVCTL=3,1,1


  ctrl+x  退出命令模式
验证 USB 4G 模块的拨号与联网功能。

### 拨号及 Ping 测试

```bash
# 通过 usb0 接口获取 IP
udhcpc -i usb0

# 测试外网连通性
ping www.baidu.com -I usb0
```

### 验证要点

| 检查项       | 预期结果              |
|-------------|----------------------|
| `ifconfig`  | usb0 接口获得 IP 地址  |
| `ping` 外网 | 正常收到 ICMP 回复     |

## 6. 门锁测试



root@Lechi:~#  od -x /dev/input/event0
0000000 5004 6a15 36d2 0007 0001 0094 0001 0000
0000020 5004 6a15 36d2 0007 0000 0000 0000 0000
0000040 5005 6a15 e894 0001 0001 0094 0000 0000
0000060 5005 6a15 e894 0001 0000 0000 0000 0000
0000100 5005 6a15 62a8 0002 0001 0094 0001 0000
0000120 5005 6a15 62a8 0002 0000 0000 0000 0000
0000140 5005 6a15 8123 0002 0001 0094 0000 0000
0000160 5005 6a15 8123 0002 0000 0000 0000 0000
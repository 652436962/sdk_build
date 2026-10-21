# WiFi 模块测试程序

RK3568（飞凌 OK3568-C，Buildroot）上的两块测试用程序：

1. **tcpserver** —— TCP 服务端，接收各设备消息，按来源 IP 分文件记录（带时间戳）。
2. **WiFi 热点（S99wifi-ap）** —— 用 PCIe 无线网卡（QCA988X/ath10k）开 AP 热点。

---

## 一、目录内容

```
wifi模块测试程序/
├── README.md
├── S99wifi-ap              # WiFi 热点启动脚本
├── clients.sh              # 查看已连客户端数量与 IP
├── hostapd-lechi.conf      # AP 配置（SSID/密码/信道）
├── dnsmasq-lechi.conf      # DHCP/DNS 配置
└── tcpserver/              # TCP 服务端（单独目录）
    ├── tcpserver.c         # 源码
    ├── Makefile            # 交叉编译规则
    ├── tcpserver           # 已编译 aarch64 静态二进制
    └── S99tcpserver        # 启动脚本
```

---

## 二、编译 tcpserver

工具链为 SDK 自带 aarch64 工具链，`Makefile` 已默认指向（相对路径）。

```bash
cd tcpserver
make            # 交叉编译 -> tcpserver (aarch64 静态)
make NATIVE=1   # 本机 x86 调试
make clean
```

- 容器内编译可覆盖：`make CROSS=/workspace/OK3568-linux-source/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-`
- 依赖：内核需有 `CONFIG_ATH10K` 等无线模块与对应固件（见同级 `../Linux/RK3568_高通PCIE_WiFi/README.md`）。

---

## 三、部署到板子

板子默认账号 `root` / 密码 `root`。两种方式：

**SSH（推荐，需网络可达）**
```bash
cd tcpserver
scp tcpserver      root@<板子IP>:/lechi/tcpserver
scp S99tcpserver   root@<板子IP>:/etc/init.d/S99tcpserver
ssh root@<板子IP> 'chmod +x /lechi/tcpserver /etc/init.d/S99tcpserver'
```

**串口 ZMODEM（无网络时）**
```bash
# 主机先进入程序目录: cd tcpserver
# 板端: cd /usr/bin && rz -y -b        ; 主机: sz -b tcpserver
# 板端: cd /etc/init.d && rz -y -b     ; 主机: sz -b S99tcpserver
# 之后 chmod +x
```

---

## 四、tcpserver 用法

### 启动 / 管理
```bash
/etc/init.d/S99tcpserver start      # 后台启动，监听 0.0.0.0:1500
/etc/init.d/S99tcpserver status
/etc/init.d/S99tcpserver restart
/etc/init.d/S99tcpserver stop
```
`S99` 命名放在 `/etc/init.d/`，开机自动启动。

### 直接运行（可选参数）
```bash
tcpserver [-p 端口] [-b 绑定IP] [-d 日志目录]
# 默认: 0.0.0.0:1500, 日志目录 /lechi/logs
```

### 行为
- 每个客户端连接 fork 一个子进程处理，支持多客户端并发；
- 收到的数据同时打印到 **stdout** 与 **/dev/console（串口）**；
- 收到的数据**原样回显**给客户端；
- 按**来源 IP** 写入独立文件，每条消息带时间戳。

### 日志格式
目录 `/lechi/logs/`，文件名为来源 IP（如 `172.31.1.5.log`）：
```
[YYYY-MM-DD HH:MM:SS] <ip>:<port> <N> bytes  <原始消息>
```
示例：
```
[2026-10-12 03:15:29] 172.31.4.1:51555 283 bytes  $LOGIN,YPRES00,N01,1,20261012111525,...512
```

### 查看
```bash
ls -l /lechi/logs/                  # 所有设备(IP)的日志文件
cat  /lechi/logs/172.31.1.5.log     # 看某台设备
tail -f /lechi/logs/172.31.1.5.log  # 实时看某台设备
```

---

## 五、WiFi 热点（S99wifi-ap）

打开无线网卡热点（**不含 NAT 转发**，如需上网另配 NAT）。

### 配置
`hostapd-lechi.conf`：
```
interface=wlp1s0
driver=nl80211
ssid=test
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1
auth_algs=1
wpa=2
wpa_passphrase=test123456
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_pairwise=CCMP
```
`dnsmasq-lechi.conf`：
```
interface=wlp1s0
bind-interfaces
except-interface=lo
dhcp-range=172.31.100.100,172.31.100.200,255.255.0.0,12h
dhcp-option=3,172.31.100.1
dhcp-option=6,172.31.100.1
```

### 部署
```bash
scp hostapd-lechi.conf root@<板子IP>:/etc/hostapd-lechi.conf
scp dnsmasq-lechi.conf root@<板子IP>:/etc/dnsmasq-lechi.conf
scp S99wifi-ap        root@<板子IP>:/etc/init.d/S99wifi-ap
ssh root@<板子IP> 'chmod +x /etc/init.d/S99wifi-ap'
```

### 启动 / 管理
```bash
/etc/init.d/S99wifi-ap start      # 起热点 hostapd + dnsmasq
/etc/init.d/S99wifi-ap status     # addr/proc/ap/clients
/etc/init.d/S99wifi-ap clients    # 只看已连客户端(MAC/信号/IP)
/etc/init.d/S99wifi-ap restart
/etc/init.d/S99wifi-ap stop
```

AP 默认：SSID `test` / 密码 `test123456`，板端地址 `172.31.100.1/16`，DHCP 池 `172.31.100.100~200`。

### 查看已连客户端数量与 IP
```bash
/lechi/clients.sh            # 自动探测无线接口(优先 AP 模式，wlan0/wlp1s0 均可)
/lechi/clients.sh wlan0      # 也可显式指定接口
```
输出示例：
```
wifi=wlp1s0  connected clients: 14
MAC                IP               SIGNAL
8c:bf:ea:8d:8f:1c  172.31.4.2       -72
20:6e:f1:88:23:10  172.31.5.1       -73
...
```

### 客户端上外网（NAT，可选）
热点本身不转发；需要上网时在板子上另做（见 `../Linux/RK3568_高通PCIE_WiFi/README.md` 第 10.4 节）：
```bash
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

---

## 六、典型联调流程

1. `S99wifi-ap start` 开热点，设备连上 WiFi（`test` / `test123456`）。
2. `S99tcpserver start` 开服务端，监听 `1500`。
3. 设备（按 IP 区分）向 `172.31.100.1:1500` 发消息。
4. 板端实时看：`tail -f /lechi/logs/<设备IP>.log`。

---

## 七、常见问题

| 现象 | 处理 |
|------|------|
| `Permission denied` 执行脚本 | `chmod +x /etc/init.d/S99tcpserver /etc/init.d/S99wifi-ap` |
| 1500 端口没监听 | `pidof tcpserver`；`killall tcpserver` 后重新 start；看 `/lechi/tcpserver.log` |
| 日志目录不存在 | 程序会自动创建 `/lechi/logs/`；也可 `mkdir -p` |
| 收不到某设备数据 | 确认该设备连的是本 AP（`S99wifi-ap clients` 看 MAC/IP），且目标端口 1500 |
| AP 起不来 | `iw dev wlp1s0 info` 看是否 `type AP`；`dmesg | grep ath10k` 查驱动/固件 |
| SSH 连不上 | 确认与板子同一二层网络；板子 `pidof sshd`、`netstat -lnt | grep :22` |

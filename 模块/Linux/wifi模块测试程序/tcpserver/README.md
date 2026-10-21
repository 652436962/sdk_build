# tcpserver — TCP 服务端（按 IP 分文件记录）

RK3568（飞凌 OK3568-C，Buildroot，aarch64）上的测试用 TCP 服务端。接收各设备发来的消息，
**按来源 IP 分文件记录（带时间戳）**，同时打印到串口控制台，并把数据**原样回显**给客户端。

---

## 一、功能

- 监听 TCP（默认 `0.0.0.0:1500`），每个连接 fork 一个子进程，支持多客户端并发；
- 收到的数据同步打印到 **stdout** 与 **/dev/console（串口控制台）**，并原样回显；
- 按来源 IP 写入独立文件：`/lechi/logs/<IP>.log`；
- 每条消息前缀时间戳：`[YYYY-MM-DD HH:MM:SS] <ip>:<port> <N> bytes  <原始消息>`。

---

## 二、文件

| 文件 | 说明 |
|------|------|
| `tcpserver.c` | 源码 |
| `Makefile` | 交叉编译规则（aarch64 静态 + strip） |
| `tcpserver` | 已编译的 aarch64 静态二进制 |
| `S99tcpserver` | 启动脚本（部署到板端 `/etc/init.d/`） |

---

## 三、编译

工具链用 SDK 自带的 aarch64 工具链，`Makefile` 已默认指向（相对路径）。

```bash
make            # 交叉编译 -> tcpserver (aarch64 静态)
make NATIVE=1   # 本机 x86 调试
make clean
```

工具链不在 PATH 或路径不同时，用 `CROSS=` 覆盖，例如容器内：

```bash
make CROSS=/workspace/OK3568-linux-source/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
```

---

## 四、部署到板子

程序与生成文件都放在板端 **`/lechi`** 下：
- 程序：`/lechi/tcpserver`
- 每 IP 日志：`/lechi/logs/<IP>.log`
- 汇总日志：`/lechi/tcpserver.log`

板子默认账号 `root` / 密码 `root`。两种方式任选。

**SSH（推荐，需网络可达）**
```bash
ssh root@<板子IP> 'mkdir -p /lechi/logs'
scp tcpserver      root@<板子IP>:/lechi/tcpserver
scp S99tcpserver   root@<板子IP>:/etc/init.d/S99tcpserver
ssh root@<板子IP> 'chmod +x /lechi/tcpserver /etc/init.d/S99tcpserver'
```

**串口 ZMODEM（无网络时）**
```bash
# 主机先进入程序目录: cd tcpserver
# 板端: mkdir -p /lechi && cd /lechi && rz -y -b     ; 主机: sz -b tcpserver
# 板端: cd /etc/init.d && rz -y -b                    ; 主机: sz -b S99tcpserver
# 之后 chmod +x /lechi/tcpserver /etc/init.d/S99tcpserver
```

---

## 五、运行

### 脚本管理
```bash
/etc/init.d/S99tcpserver start      # 后台启动，监听 0.0.0.0:1500，日志写 /lechi/tcpserver.log
/etc/init.d/S99tcpserver status
/etc/init.d/S99tcpserver restart
/etc/init.d/S99tcpserver stop
```
以 `S99` 命名放在 `/etc/init.d/`，开机自动启动。

### 直接运行
```bash
tcpserver [-p 端口] [-b 绑定IP] [-d 日志目录]
#   默认: 0.0.0.0:1500，日志目录 /lechi/logs
```

| 参数 | 含义 | 默认 |
|------|------|------|
| `-p` | 监听端口 | `1500` |
| `-b` | 绑定地址 | `0.0.0.0` |
| `-d` | 每 IP 日志目录 | `/lechi/logs` |

---

## 六、日志

目录 `/lechi/logs/`，文件名为来源 IP：
```
/lechi/logs/172.31.1.5.log
/lechi/logs/192.168.1.103.log
...
```
内容示例：
```
[2026-10-12 03:15:29] 172.31.4.1:51555 283 bytes  $LOGIN,YPRES00,N01,1,20261012111525,...512
[2026-10-12 03:15:32] 172.31.1.5:8888 99 bytes  $DATADICK,V202201,SD002,YHUMI00,N01,...
```

查看：
```bash
ls -l /lechi/logs/                  # 所有设备(IP)的日志文件
cat  /lechi/logs/172.31.1.5.log     # 某台设备的全部消息
tail -f /lechi/logs/172.31.1.5.log  # 实时看某台设备
```

---

## 七、测试

```bash
# 板端本机自测
exec 3<>/dev/tcp/127.0.0.1/1500; printf 'hello\n' >&3; sleep 1; exec 3>&-
# 会生成 /lechi/logs/127.0.0.1.log

# 另一台机器（网络可达时）
nc 192.168.1.102 1500      # 发字符，板端日志与原样回显可见
```

---

## 八、常见问题

| 现象 | 处理 |
|------|------|
| 执行脚本 `Permission denied` | `chmod +x /etc/init.d/S99tcpserver` |
| 1500 端口没监听 | `pidof tcpserver`；`killall tcpserver` 后重新 start；看 `/lechi/tcpserver.log` |
| 收不到某设备数据 | 确认该设备与本板网络互通，且目标端口为 1500 |
| 日志目录不存在 | 程序自动创建 `/lechi/logs/`；也可 `mkdir -p` |
| 想换端口/日志目录 | `tcpserver -p 8888 -d /data/tcplogs` |

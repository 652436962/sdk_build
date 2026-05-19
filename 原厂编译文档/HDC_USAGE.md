# 华为 HDC 使用说明

## 简介

HDC（HarmonyOS Device Connector）是华为为 OpenHarmony / HarmonyOS 设备提供的命令行调试工具，类似于 Android 的 `adb`，支持文件传输、Shell 调试、应用安装、日志获取、端口转发等功能。

> 安装方法请参考 [HDC_INSTALL.md](./HDC_INSTALL.md)

---

## 一、设备连接与基础命令

### 1.1 启动 / 关闭 hdc 服务
```bash
# 启动后台服务
hdc start

# 重启服务（设备未识别时常用）
hdc kill && hdc start

# 关闭服务
hdc kill
```

### 1.2 查看已连接设备
```bash
# 列出所有连接的设备
hdc list targets

# 显示详细信息（USB / TCP / 状态）
hdc list targets -v
```
输出示例：
```
192.168.1.100:5555    Connected
1234567890ABCDEF      Connected
```

### 1.3 指定目标设备
当连接多台设备时，使用 `-t <connect_key>` 指定目标：
```bash
hdc -t 1234567890ABCDEF shell
```

### 1.4 查看版本与帮助
```bash
hdc --version           # 查看版本
hdc -h                  # 查看完整命令列表
hdc <command> -h        # 查看子命令帮助
```

---

## 二、Shell 调试

### 2.1 进入设备 Shell
```bash
# 交互式 Shell
hdc shell

# 直接执行命令并返回
hdc shell "ls /data"
hdc shell "ps -ef | grep render_service"
hdc shell "cat /proc/cpuinfo"
```

### 2.2 常用设备 Shell 命令
| 命令 | 说明 |
|------|------|
| `param get const.product.name` | 查看产品名 |
| `param get const.ohos.apiversion` | 查看 API 版本 |
| `bm dump -a` | 列出所有已安装应用 |
| `aa start -a <ability> -b <bundle>` | 启动指定 Ability |
| `power-shell setmode 602` | 设置常亮模式 |
| `hilog` | 查看实时日志 |
| `reboot` | 重启设备 |

---

## 三、文件传输

### 3.1 推送文件到设备（PC → 设备）
```bash
hdc file send <local-path> <remote-path>

# 示例
hdc file send ./test.hap /data/local/tmp/
hdc file send -cwd ./res /data/app/res    # 使用相对路径基准
```

### 3.2 从设备拉取文件（设备 → PC）
```bash
hdc file recv <remote-path> <local-path>

# 示例
hdc file recv /data/log/hilog/hiappevent.db ./
hdc file recv /data/storage/el2/base/files/ ./backup/
```

### 3.3 注意事项
- 设备路径区分大小写
- `/data/local/tmp/` 是常用的临时目录，权限宽松
- 大文件传输建议使用 USB 而非 TCP

### 3.4 推送到只读分区（必须 remount）

`/`、`/system`、`/vendor` 等系统分区默认以只读方式挂载，直接推送会报 `Read-only file system` 错误，必须先重新挂载为可读写：

```bash
# 1. 关闭权限验证（如需）

hdc shell mount -o rw,remount /

# 2. 推送文件到只读分区
hdc file send ./mylib.so /system/lib/
hdc file send ./config.xml /vendor/etc/

# 3. 重启生效
hdc shell sync
hdc shell reboot
```

> **说明**：
> - 推送到 `/data/**`（包括 `/data/local/tmp/`）**不需要 remount**，该分区默认可写
> - 部分设备需要先执行 `hdc shell "setenforce 0"` 关闭 SELinux
> - 重启后系统分区会重新变为只读，需重新执行 remount

---

## 四、应用安装与卸载

### 4.1 安装 HAP 包
```bash
# 安装应用
hdc install <path-to-hap>

# 强制覆盖安装
hdc install -r <path-to-hap>

# 安装并保留数据（升级）
hdc install -r -k <path-to-hap>

# 示例
hdc install -r ./entry-default-signed.hap
```

### 4.2 卸载应用
```bash
hdc uninstall <bundleName>

# 保留数据卸载
hdc uninstall -k <bundleName>

# 示例
hdc uninstall com.example.myapp
```

### 4.3 启动应用
```bash
hdc shell aa start -a <abilityName> -b <bundleName>

# 示例
hdc shell aa start -a EntryAbility -b com.example.myapp
```

---

## 五、TCP/IP 无线调试

### 5.1 切换到 TCP 模式
```bash
# 1. 先用 USB 连接设备
hdc list targets

# 2. 切换设备到 TCP 监听模式（默认端口 5555）
hdc tmode port 5555

# 3. 拔掉 USB，通过 IP 连接
hdc tconn 192.168.1.100:5555

# 4. 验证
hdc list targets
```

### 5.2 断开 TCP 连接
```bash
hdc tconn 192.168.1.100:5555 -remove
```

### 5.3 切回 USB 模式
```bash
hdc tmode usb
```

---

## 六、端口转发

### 6.1 PC 端口 → 设备端口（forward）
将 PC 本地端口转发至设备端口，用于本地访问设备服务：
```bash
hdc fport tcp:18080 tcp:8080
# PC 上访问 localhost:18080 即等同访问设备 8080 端口
```

### 6.2 设备端口 → PC 端口（reverse）
将设备端口反向转发到 PC：
```bash
hdc rport tcp:8080 tcp:18080
# 设备上访问 localhost:8080 即等同访问 PC 18080 端口
```

### 6.3 查看与移除转发
```bash
hdc fport ls                      # 查看所有 forward
hdc fport rm tcp:18080 tcp:8080   # 移除指定 forward
```

---

## 七、日志查看（hilog）

### 7.1 实时日志
```bash
# 查看所有日志
hdc shell hilog

# 按级别过滤（D/I/W/E/F）
hdc shell hilog -L E

# 按 Tag 过滤
hdc shell hilog -T MyAppTag

# 持久化输出到文件
hdc shell hilog > device.log
```

### 7.2 清空日志
```bash
hdc shell hilog -r
```

### 7.3 设置日志级别
```bash
hdc shell hilog -b D            # 全局调试级别
hdc shell hilog -b W -T MyApp   # 指定 Tag 级别
```

---

## 八、常用诊断命令

| 用途 | 命令 |
|------|------|
| 查看设备型号 | `hdc shell param get const.product.model` |
| 查看系统版本 | `hdc shell param get const.ohos.fullname` |
| 查看 CPU 信息 | `hdc shell cat /proc/cpuinfo` |
| 查看内存信息 | `hdc shell cat /proc/meminfo` |
| 查看运行进程 | `hdc shell ps -ef` |
| 截屏 | `hdc shell snapshot_display -f /data/local/tmp/screen.png` |
| 录屏 | `hdc shell screen_record /data/local/tmp/screen.mp4` |

---

## 九、常见问题

### 9.1 `[Empty]` —— 设备未识别
- 确认 USB 数据线非充电线
- 确认设备已开启"开发者模式 → USB 调试"
- 重启 hdc 服务：`hdc kill && hdc start`
- 检查 udev 规则（参考 HDC_INSTALL.md 第 50-66 行）

### 9.2 多设备冲突
当同时连接多台设备时，必须使用 `-t <connect_key>` 指定目标：
```bash
hdc -t 1234567890ABCDEF shell
```

### 9.3 文件推送失败 `[Fail]File transfer failed`
- 检查设备路径是否存在与可写
- `/system` 等只读分区无法直接写入
- 优先使用 `/data/local/tmp/` 作为临时落点

### 9.4 安装 HAP 失败 `code: 9568347`
- HAP 未签名或签名不匹配，需使用 IDE 重新签名
- 或使用 `hdc install -r` 强制覆盖安装

### 9.5 TCP 连接失败
- 确认 PC 与设备处于同一局域网
- 防火墙未阻断 5555 端口
- 设备端 `tmode port 5555` 命令是否成功执行

---

## 十、参考资料

- OpenHarmony 官方 hdc 文档：https://gitee.com/openharmony/developtools_hdc
- HarmonyOS DevEco Studio：https://developer.huawei.com/consumer/cn/deveco-studio/
- 安装说明：[HDC_INSTALL.md](./HDC_INSTALL.md)

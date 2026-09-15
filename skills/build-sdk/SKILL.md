---
name: build-sdk
description: SDK 编译任务选择器，引导用户在 T527 / T113i / RK3562 / RK3562 Huayun / RK3568 五个嵌入式平台中选择目标平台并按对应 build_*_script.md 文档执行 Docker 容器启动、SDK 编译与固件打包流程。当用户说"编译 SDK"、"编译固件"、"build sdk"、"build firmware"、"开始编译"、"打包固件"、"刷机镜像"等需要构建嵌入式 Linux/OpenHarmony 镜像的指令时使用。
---

# Build SDK 任务选择器

## 触发场景

当用户表达以下意图时启用本 Skill：

- "编译 SDK" / "编译固件" / "build sdk" / "build firmware"
- "开始编译" / "重新编译" / "全量编译"
- "打包固件" / "生成镜像" / "出刷机包"
- 提到具体平台名（T527、T113i、RK3562、RK3568、RK3568 Ubuntu）并要求构建

使用中文回复我

## 工作流程

### 步骤 1：识别目标平台

读取下方"可用平台列表"表格，与用户的输入做匹配：

- 用户已指定平台 → 直接进入步骤 2
- 用户未指定平台 → 用 AskUserQuestion 让用户从 5 个选项中选择

### 步骤 2：读取对应平台的详细文档

每个平台都有独立的 `build_*_script.md` 文档，包含完整的编译/打包/常见问题章节。**必须先读取文档**，再按文档指令执行：

```bash
# T527
read_file /media/lechi/linuxsdk/linuxsdk/build_T527_linuxsdk_script.md
# T527 OpenHarmony 5.0
read_file /media/lechi/linuxsdk/linuxsdk/build_T527_ubuntu20_op_script.md
# T113i
read_file /media/lechi/linuxsdk/linuxsdk/build_T113i_script.md
# RK3562
read_file /media/lechi/linuxsdk/linuxsdk/build_rk3562_script.md
# RK3562 Huayun（华云分支）
read_file /media/lechi/linuxsdk/linuxsdk/build_huayun_script.md
# RK3568 Buildroot
read_file /media/lechi/linuxsdk/linuxsdk/build_ok3568_script.md
# RK3568 Ubuntu (Forlinx Desktop 20.04)
read_file /media/lechi/linuxsdk/linuxsdk/build_rk3568_ubuntu22_script.md
```

### 步骤 3：环境检查（容器内编译统一三连）

```bash
# 1) 容器是否存在
docker ps -a | grep -E "t527|t113i|rk3562|huayun|ok3568"
# 2) SDK 目录权限
ls -la /media/lechi/linuxsdk/linuxsdk/ | grep -E "t527|tina|rk3562|huayun|rk3568|openharmony"
# 3) 是否需要 chown -R $USER:$USER（参见对应文档"权限问题"小节）
```

### 步骤 4：按文档执行编译

使用 `docker exec -d` 后台启动并 `tee build.log`，避免长流程因终端断连失败。

#### 持续监控编译状态

**Agent 必须在启动编译后主动轮询日志，直到编译完成，不可只告知用户自行监控。**

```bash
# 方式一：持续滚动（Ctrl+C 退出）
docker exec <容器名> tail -f <SDK路径>/build.log

# 方式二：定时轮询（配合 watch 自动刷新）
watch -n 5 "docker exec <容器名> tail -20 <SDK路径>/build.log"
```

**Agent 轮询策略**：

1. 启动 `docker exec -d` 后，等待 5~8 秒让编译初始化
2. 执行 `tail -30` 检查日志是否开始输出，确认编译已进入编译阶段
3. 每隔 60 秒用 `tail -20` 快速检查进度，向用户报告当前阶段（如 brandy / kernel / buildroot）
4. 当检测到完成标志后，进入步骤 5

各平台监控命令速查：

| 平台 | 容器名 | build.log 路径 | 成功标志 |
|------|--------|----------------|----------|
| T527 Linux | `t527_linuxsdk` | `/workspace/OKT527-linux-sdk/build.log` | `=====build  successful=====` |
| T527 OH5.0 | `t527_openharmony` | `/home/openharmony/forlinx-5.0-release/build.log` | `=====build  successful=====` |
| T113i | `t113i-sdk` | `/workspace/tina5.0_v1.0/build.log` | `INFO: build OK.` + `pack finish` |
| RK3562 | `rk3562-sdk` | `/home/ubuntu/rk3562/build.log` | `=====build  successful=====` |
| RK3562 Huayun | `huayun-sdk` | `/workspace/build.log` | `=====build  successful=====` |
| RK3568 Buildroot | `rk3568_sdk` | `/home/ubuntu/OK3568-linux-source/build.log` | `=====build  successful=====` |
| RK3568 Ubuntu | `rk3568_ubuntu` | `/workspace/OK3568-linux-source/build.log` | `=====build  successful=====` |

编译完成标志：各平台略有不同 — T113i 为 `INFO: build OK.`（编译）+ `pack finish`（打包），其余平台类似 `=====build  successful=====`

### 步骤 5：询问是否烧写固件

编译 + 打包全部成功后，**必须**用 `AskUserQuestion` 询问用户：

> "编译已成功完成，是否需要将固件烧写到开发板？"

- 用户选择"跳过" → 结束流程，告知固件路径
- 用户选择对应烧写方式 → 根据下方「各平台烧写命令」执行

烧写前先确认设备连接：

```bash
# Rockchip 平台（RK3562 / RK3568）
lsusb | grep -i rockchip
openrockcli scan

# Allwinner 平台（T113i / T527）
openixcli scan
```

**Rockchip 平台特殊流程（重要）**：若 `openrockcli scan` 未检测到处于 Maskrom/Loader 模式的设备，不要直接结束或让用户手动按键，而是按以下流程引导设备进入烧写模式：

1. 自动枚举本机串口：`ls -l /dev/ttyUSB* /dev/ttyACM*`（详见「各平台烧写命令 → Rockchip 串口引导进入烧写模式」）
2. 将检测到的串口列表展示给用户，用 `AskUserQuestion` 让用户选择开发板调试串口对应的设备节点
3. 向所选串口发送 `reboot loader`，等待 5~10 秒让设备重新枚举
4. 再次 `openrockcli scan` 确认设备已进入 Loader/Maskrom 模式，再执行烧写

---

## 可用平台列表

| 序号 | 平台 | 开发板 | 编译文档 | OS 形态 |
|------|------|--------|----------|---------|
| 1 | T527 | 飞凌 OK527-C | `build_T527_linuxsdk_script.md` | Linux |
| 1.1 | T527 OH5.0 | 飞凌 OK527-C | `build_T527_ubuntu20_op_script.md` | OpenHarmony 5.0 |
| 2 | T113i | 创龙 TL113i | `build_T113i_script.md` | Tina Linux 5.0 |
| 3 | RK3562 | 创龙 TL3562 | `build_rk3562_script.md` | Buildroot / Ubuntu |
| 3.1 | RK3562 Huayun | 创龙 TL3562 | `build_huayun_script.md` | Buildroot / Ubuntu（华云分支） |
| 4 | RK3568 | 飞凌 OK3568-C | `build_ok3568_script.md` | Buildroot |
| 5 | RK3568 Ubuntu | 飞凌 OK3568-C | `build_rk3568_ubuntu22_script.md` | Forlinx Desktop 20.04 |

---

## 各平台快捷命令

### T527 OpenHarmony 5.0

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/t527_openharmony/

# 启动并进入容器
docker start t527_openharmony
docker exec -it t527_openharmony /bin/bash

# 容器内：首次必须先跑预编译工具链（约 10 GB）
cd /home/openharmony/forlinx-5.0-release
bash build/prebuilts_download.sh 2>&1 | tee prebuilts_download.log

# 全量编译（带日志）
./build.sh --product-name okt527 --ccache 2>&1 | tee build.log

# 打包
cd device/board/forlinx/okt527/kernel/build/
./pack.sh
```

### T113i Tina Linux

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5

# 启动并进入容器
docker start t113i-sdk
docker exec -it t113i-sdk /bin/bash

# 容器内：编译 + 打包（两步都必须执行，否则不生成最终 .img 镜像）
cd /workspace/tina5.0_v1.0
source build/envsetup.sh
./build.sh          # 编译内核、U-Boot、rootfs
./build.sh pack     # 打包生成最终 .img 刷机镜像（必须显式执行）
```

> **后台编译**：`./build.sh` 和 `./build.sh pack` 必须链式执行，缺一不可：
> ```bash
> docker exec -d t113i-sdk bash -c \
>   "cd /workspace/tina5.0_v1.0 && source build/envsetup.sh && ./build.sh 2>&1 | tee build.log && ./build.sh pack 2>&1 | tee -a build.log"
> ```

### RK3562 Buildroot

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3562_sdk

# 启动并进入容器
docker start rk3562-sdk
docker exec -it rk3562-sdk /bin/bash

# 容器内：全量编译（约 1~2 小时，最终 update.img 约 5.9G）
cd /home/ubuntu/rk3562
./build.sh all
```

### RK3562 Huayun（华云分支）

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/huayun_sdk

# 启动并进入容器
docker start huayun-sdk
docker exec -it huayun-sdk /bin/bash

# 容器内：全量编译（容器已预配置依赖和修复）
cd /workspace && ./ubuntu/build.sh all
```

### RK3568 Buildroot

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk

# 启动并进入容器
docker start rk3568_sdk
docker exec -it rk3568_sdk /bin/bash

# 容器内：全量编译
cd /home/ubuntu/OK3568-linux-source
./build.sh
```

### RK3568 Ubuntu (Forlinx Desktop 20.04)

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu

# 启动并进入容器
docker start rk3568_ubuntu
docker exec -it rk3568_ubuntu /bin/bash

# 容器内：全编译 + 打包 Ubuntu 镜像
cd /workspace/OK3568-linux-source
./build.sh
ln -rsf ubuntu-20.04-release/parameter.txt rockdev/parameter.txt
ln -rsf ubuntu-20.04-release/ubuntu.img rockdev/rootfs.img
./build.sh updateimg
# 输出: rockdev/update.img
```

---

## 各平台烧写命令

烧写通过宿主机（非容器内）执行。Linux 下使用 USB OTG 线连接开发板。

> 💡 **Rockchip 免按键引导**：若设备未处于烧写模式，可自动检测调试串口 → 与用户确认串口 → 发送 `reboot loader` 进入 Loader 模式 → 确认后再烧写。详细步骤见下方「Rockchip 串口引导进入烧写模式」小节。

### 烧写前准备

```bash
# 检查烧写工具是否可用
which openrockcli     # Rockchip 平台
which openixcli       # Allwinner 平台

# openrockcli 的 flash/devices/inspect/unpack 底层委托 upgrade_tool，
# 若宿主机未安装 upgrade_tool，通过环境变量指向 SDK 自带工具：
# export OPENROCKCLI_UPGRADE_TOOL=/path/to/upgrade_tool

# 扫描已连接设备
openixcli scan        # Allwinner
openrockcli scan      # Rockchip

# 检测调试串口（Rockchip 串口引导进入烧写模式用）
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
ls -l /dev/serial/by-id/ 2>/dev/null
```

### 设备进入烧写模式

| 平台 | 进入方式 |
|------|----------|
| **T113i** | 断电 → 按住 FEL 键 → 上电 → 松键 |
| **T527** | 断电 → 按住 FEL 键 → 上电 → 松键 |
| **RK3562** | 方式一：断电 → 按住 RECOVERY → 上电 → 2 秒后松键；方式二：调试串口发送 `reboot loader` |
| **RK3562 Huayun** | 方式一：断电 → 按住 RECOVERY → 上电 → 2 秒后松键；方式二：调试串口发送 `reboot loader` |
| **RK3568** | 方式一：断电 → 按住 RECOVERY → 上电 → 2 秒后松键；方式二：调试串口发送 `reboot loader` |

### Rockchip 串口引导进入烧写模式（免按键）

> 适用于设备当前处于系统正常运行状态（未进入 Maskrom/Loader）的场景。通过调试串口发送 `reboot loader` 让设备重启进入 Loader 烧写模式，无需按键。参考 `原厂文档/openrockcli_Tutorial.md` 与 `原厂文档/upgrade_tool_Tutorial.md`。

**步骤 1：自动检测串口**

```bash
# 枚举本机串口设备（ttyUSB=USB 转串口芯片，ttyACM=USB CDC）
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# 查看串口芯片与设备节点的对应关系（CH340 / CP210x / FT232 等）
ls -l /dev/serial/by-id/ 2>/dev/null
```

**步骤 2：与用户确认串口**

将步骤 1 检测到的串口列表展示给用户，用 `AskUserQuestion` 让用户选择开发板调试串口对应的设备节点（常见 `/dev/ttyUSB0`）。若检测到多个串口，务必以用户选择为准，避免向错误串口发送指令。

**步骤 3：向所选串口发送 `reboot loader`**

```bash
# 方式一：脚本化直接写入，波特率以开发板调试串口为准（常见 115200，部分板子 1500000）
sudo stty -F /dev/ttyUSB0 115200 cs8 -cstopb -parenb
printf 'reboot loader\r\n' | sudo tee /dev/ttyUSB0 > /dev/null
```

```bash
# 方式二：picocom 交互式发送
sudo picocom -b 115200 /dev/ttyUSB0
# 在终端输入 reboot loader 并回车，然后按 Ctrl+A Ctrl+X 退出 picocom
```

> 若设备已启动进入 Linux 系统，`reboot loader` 需在 U-Boot 阶段生效；也可在上电时于调试串口按 **Ctrl+D** 直接进入 Loader 模式。

**步骤 4：等待设备重新枚举并确认烧写模式**

```bash
# 等待 5~10 秒让设备重启并重新枚举
sleep 8

# 确认设备已进入 Loader / Maskrom 模式
openrockcli scan

# 若仍未检测到，可重试一次 reboot loader，或改用 RECOVERY 键方式进入
```

**步骤 5：烧写固件**

确认设备处于烧写模式后，按下方对应平台的 `openrockcli flash` 命令执行烧写。

### T113i Tina Linux（Allwinner，openixcli）

> ⚠️ 执行前请将开发板进入 FEL 烧写模式（断电 → 按住 FEL 键 → 上电 → 等待2秒 → 松键）

```bash
# 1. 扫描设备（应先进入 FEL 模式再执行）
openixcli scan

# 2. 烧写固件
openixcli flash /media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5/tina5.0_v1.0/out/t113_i_linux_tlt113-evm-emmc_uart0.img

# 常用选项：
# openixcli flash --verify false <img>    # 跳过校验（加速）
# openixcli flash --mode partition <img>  # 仅烧写分区（保留数据）
```

### T527 Linux / T527 OH5.0（Allwinner，openixcli）

> ⚠️ 执行前请将开发板进入 FEL 烧写模式（断电 → 按住 FEL 键 → 上电 → 等待2秒 → 松键）

```bash
# 1. 扫描设备（未扫描到则等待5s后重试）
openixcli scan || (sleep 5 && openixcli scan)

# 2. 烧写固件（路径见「编译输出路径」表格）
openixcli flash /media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/out/t527_linux_okt527_uart0.img

# T527 OH5.0 镜像：
# openixcli flash /media/lechi/linuxsdk/linuxsdk/t527_openharmony/forlinx-5.0-release/out/t527_linux_okt527_uart0.img
```

### RK3562 ubuntu（Rockchip，upgrade_tool 推荐）

> ⚠️ 执行前请将开发板进入 **Maskrom** 烧写模式（断电 → 按住 RECOVERY → 上电 → 2 秒后松键）

> 💡 **实践经验**：本平台 update.img 约 5.8GB（rootfs 占绝大部分），在 Loader 模式下烧写容易在 rootfs 写入中途 USB 断开失败（`Download Firmware Fail`）。**Maskrom 模式下直接 `upgrade_tool uf` 烧写一次成功率最高**。

```bash
# 1. 检查设备连接（应显示 Maskrom 模式，未检测到则等待5s后重试）
openrockcli scan || (sleep 5 && openrockcli scan)

# 2. 全量烧写 update.img（Maskrom 下 upgrade_tool 自动下载 loader 初始化芯片并烧写）
upgrade_tool uf /media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rockchip/output/update/Image/update.img

# 预期输出：
# Download IDB Success
# Download Image... (100%)
# Download Firmware Success
# Upgrade firmware ok.

# 烧写完成后设备自动重启
```

**备选：openrockcli 烧写**（等价，底层同样委托 upgrade_tool UF）：

```bash
openrockcli scan
openrockcli flash /media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rockchip/output/update/Image/update.img
# openrockcli flash <img> --verify true            # 启用校验
# openrockcli flash <img> --mode full_erase        # 全量擦除后烧写
# openrockcli flash <img> --post-action poweroff   # 烧写完成后关机
```

### RK3562 Huayun（Rockchip，upgrade_tool 推荐）

> ⚠️ 执行前请将开发板进入 **Maskrom** 烧写模式（断电 → 按住 RECOVERY → 上电 → 2 秒后松键）

> 💡 与 RK3562 相同：update.img 体积大（rootfs 为主），**Maskrom + `upgrade_tool uf`** 最稳定。

```bash
# 1. 检查设备连接（应显示 Maskrom 模式，未检测到则等待5s后重试）
openrockcli scan || (sleep 5 && openrockcli scan)

# 2. 全量烧写 update.img
upgrade_tool uf /media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/rockchip/output/update/Image/update.img

# 烧写完成后设备自动重启
```

### RK3568 Buildroot（Rockchip，openrockcli）

> ⚠️ 执行前请将开发板进入 Maskrom/Loader 烧写模式

```bash
# 1. 检查设备连接（未扫描到则等待5s后重试）
openrockcli scan || (sleep 5 && openrockcli scan)

# 2. 全量烧写
openrockcli flash /media/lechi/linuxsdk/linuxsdk/rk3568_sdk/rockdev/update.img

# 3. 分区烧写（仅更新部分分区，openrockcli 内部解包 update.img 后按分区写入）
openrockcli flash /media/lechi/linuxsdk/linuxsdk/rk3568_sdk/rockdev/update.img \
  --mode partition --partitions boot,uboot,trust,resource,recovery

# 4. 重启设备
openrockcli reset
```

### RK3568 Ubuntu（Rockchip，openrockcli / TF 卡）

> ⚠️ 执行前请将开发板进入 Maskrom/Loader 烧写模式

```bash
# 全量烧写
openrockcli flash /media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu/rockdev/update.img

# 或写入 TF 卡后插入开发板启动
# sudo dd if=/media/lechi/linuxsdk/linuxsdk/rk3568_ubuntu/rockdev/update.img of=/dev/sdX bs=1M status=progress
```

---

## 状态检查命令

```bash
# 查看所有相关容器状态
docker ps -a | grep -E "t527_linuxsdk|t527_openharmony|t113i-sdk|rk3562-sdk|huayun-sdk|rk3568_sdk|rk3568_ubuntu"

# 查看容器运行时间
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Created}}"

# 检查 SDK 目录是否存在
ls -la /media/lechi/linuxsdk/linuxsdk/ | grep -E "t527|tina|rk3562|huayun|rk3568|openharmony"
```

---

## 编译输出路径

| 平台 | 主固件 | 打包输出 |
|------|--------|----------|
| T527 (Linux) | `out/t527_linux_okt527_uart0.img` | `out/pack_out/` |
| T527 (OH5.0) | `out/t527_linux_okt527_uart0.img` | `out/pack_out/` |
| T113i | `out/t113_i_linux_tlt113-evm-emmc_uart0.img` | `out/t113_i/tlt113-evm-emmc/pack_out/` |
| RK3562 | `ubuntu/rockchip/output/update/Image/update.img` | - |
| RK3562 Huayun | `ubuntu/rockchip/output/update/Image/update.img` | - |
| RK3568 Buildroot | `rockdev/` | - |
| RK3568 Ubuntu | `rockdev/update.img` | - |

---

## 常见注意事项

1. **首次编译 OpenHarmony 必须跑** `bash build/prebuilts_download.sh`，否则 `build.sh` 立即报错。
2. **容器名一定区分平台**：T527 Linux 用 `t527_linuxsdk`，T527 OH5.0 用 `t527_openharmony`，T113i 用 `t113i-sdk`，RK3562 用 `rk3562-sdk`，RK3562 Huayun 用 `huayun-sdk`，RK3568 Buildroot 用 `rk3568_sdk`，RK3568 Ubuntu 用 `rk3568_ubuntu`。
3. **后台长任务**：使用 `docker exec -d <name> bash -c "cmd 2>&1 | tee build.log"`，配合 `tail -f build.log` 跟踪。
4. **镜像/源码权限报错**：到本机 SDK 根目录执行 `sudo chown -R $USER:$USER .`。
5. **不打开多个并行编译**：磁盘 I/O 与内存压力会拖垮整机，逐平台串行。
6. **T113i 编译 = 两步**：`./build.sh` 只编译组件（内核、U-Boot、rootfs），**不会**生成最终 `.img` 镜像。必须显式执行 `./build.sh pack` 才能打包出刷机镜像，否则镜像文件日期不会更新。
7. **烧写前确认设备模式**：Rockchip 需 `openrockcli scan` 看到 Maskrom/Loader，Allwinner 需进入 FEL 模式。烧写全程不拔 USB 线。
8. **Rockchip 串口引导**：设备未处于烧写模式时，先自动检测串口（`ls -l /dev/ttyUSB* /dev/ttyACM*`）并与用户确认串口号，再向串口发送 `reboot loader` 进入 Loader 模式，避免反复按键。
9. **RK3562 大固件烧写**：update.img（约 5.8GB）建议在 **Maskrom 模式**下用 `upgrade_tool uf` 直接烧写；Loader 模式或 `openrockcli flash` 封装（内部仍委托 UF）易在 rootfs 写入中途 USB 断开失败（实践经验），若失败可先按键进 Maskrom 再重试。

---

## 引用文档

各平台详细步骤、常见问题、修复方案均收录在对应 `build_*_script.md` 中。本 Skill 只提供"选择 + 快捷"层级的引导，遇到细节请直接读取对应平台文档。

## 烧写工具参考

- `原厂文档/openrockcli_Tutorial.md` — OpenRockCLI（Rockchip 烧录工具）完整使用说明
- `原厂文档/upgrade_tool_Tutorial.md` — Rockchip upgrade_tool 官方烧录工具使用说明
- `原厂文档/OpenixCLI_Tutorial.md` — OpenixCLI（Allwinner 烧录工具）完整使用说明

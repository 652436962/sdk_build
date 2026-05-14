---
name: build-sdk
description: SDK 编译任务选择器，引导用户在 T527 / T113i / RK3562 / RK3568 四个嵌入式平台中选择目标平台并按对应 build_*_script.md 文档执行 Docker 容器启动、SDK 编译与固件打包流程。当用户说"编译 SDK"、"编译固件"、"build sdk"、"build firmware"、"开始编译"、"打包固件"、"刷机镜像"等需要构建嵌入式 Linux/OpenHarmony 镜像的指令时使用。
---

# Build SDK 任务选择器

## 触发场景

当用户表达以下意图时启用本 Skill：

- "编译 SDK" / "编译固件" / "build sdk" / "build firmware"
- "开始编译" / "重新编译" / "全量编译"
- "打包固件" / "生成镜像" / "出刷机包"
- 提到具体平台名（T527、T113i、RK3562、RK3568）并要求构建

## 工作流程

### 步骤 1：识别目标平台

读取下方"可用平台列表"表格，与用户的输入做匹配：

- 用户已指定平台 → 直接进入步骤 2
- 用户未指定平台 → 用 AskUserQuestion 让用户从 4 个选项中选择

### 步骤 2：读取对应平台的详细文档

每个平台都有独立的 `build_*_script.md` 文档，包含完整的编译/打包/常见问题章节。**必须先读取文档**，再按文档指令执行：

```bash
# T527
read_file /media/lechi/linuxsdk/linuxsdk/build_T527_script.md
# T527 OpenHarmony 5.0
read_file /media/lechi/linuxsdk/linuxsdk/build_T527_openharmony_script.md
# T113i
read_file /media/lechi/linuxsdk/linuxsdk/build_T113i_script.md
# RK3562
read_file /media/lechi/linuxsdk/linuxsdk/build_rk3562_script.md
# RK3568
read_file /media/lechi/linuxsdk/linuxsdk/build_ok3568_script.md
```

### 步骤 3：环境检查（容器内编译统一三连）

```bash
# 1) 容器是否存在
docker ps -a | grep -E "t527|t113i|rk3562|ok3568"
# 2) SDK 目录权限
ls -la /media/lechi/linuxsdk/linuxsdk/ | grep -E "t527|tina|rk3562|rk3568|openharmony"
# 3) 是否需要 chown -R $USER:$USER（参见对应文档"权限问题"小节）
```

### 步骤 4：按文档执行编译

使用 `docker exec -d` 后台启动并 `tee build.log`，避免长流程因终端断连失败。

---

## 可用平台列表

| 序号 | 平台 | 开发板 | 编译文档 | OS 形态 |
|------|------|--------|----------|---------|
| 1 | T527 | 飞凌 OK527-C | `build_T527_script.md` | Linux + OpenHarmony 3.2 |
| 1.1 | T527 OH5.0 | 飞凌 OK527-C | `build_T527_openharmony_script.md` | OpenHarmony 5.0 |
| 2 | T113i | 创龙 TL113i | `build_T113i_script.md` | Tina Linux 5.0 |
| 3 | RK3562 | 创龙 TL3562 | `build_rk3562_script.md` | Buildroot / Ubuntu |
| 4 | RK3568 | 飞凌 OK3568-C | `build_ok3568_script.md` | Buildroot |

---

## 各平台快捷命令

### T527 OpenHarmony 5.0

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/openharmony_T527/

# 启动并进入容器
sudo docker start okt527-oh5.0
sudo docker exec -it okt527-oh5.0 /bin/bash

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
docker start t113i
docker exec -it t113i /bin/bash

# 容器内：编译 + 打包
cd /home/ubuntu/tina
source build/envsetup.sh
./build.sh
./build.sh pack
```

### RK3562 Buildroot

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3562_sdk

# 启动并进入容器
docker start rk3562
docker exec -it rk3562 /bin/bash

# 容器内：全量编译（约 1~2 小时，最终 update.img 约 5.9G）
cd /home/ubuntu/rk3562
./build.sh all
```

### RK3568 Buildroot

```bash
# 进入 SDK 目录
cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk

# 启动并进入容器
docker start ok3568
docker exec -it ok3568 /bin/bash

# 容器内：全量编译
cd /home/ubuntu/OK3568-linux-source
./build.sh
```

---

## 状态检查命令

```bash
# 查看所有相关容器状态
docker ps -a | grep -E "t527|okt527|t113i|rk3562|ok3568"

# 查看容器运行时间
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Created}}"

# 检查 SDK 目录是否存在
ls -la /media/lechi/linuxsdk/linuxsdk/ | grep -E "t527|tina|rk3562|rk3568|openharmony"
```

---

## 编译输出路径

| 平台 | 主固件 | 打包输出 |
|------|--------|----------|
| T527 (Linux) | `out/t527_linux_okt527_uart0.img` | `out/pack_out/` |
| T527 (OH5.0) | `out/pack_out/okt527_uart0.img` | `out/pack_out/` |
| T113i | `out/t113i_uart0.img` | `out/pack_out/` |
| RK3562 | `ubuntu/rockchip/output/update/Image/update.img` | - |
| RK3568 | `OK3568-linux-source/output/` | - |

---

## 常见注意事项

1. **首次编译 OpenHarmony 必须跑** `bash build/prebuilts_download.sh`，否则 `build.sh` 立即报错。
2. **容器名一定区分平台**：T527 用 `okt527-oh5.0`，T113i 用 `t113i`，RK3562 用 `rk3562`，RK3568 用 `ok3568`。
3. **后台长任务**：使用 `docker exec -d <name> bash -c "cmd 2>&1 | tee build.log"`，配合 `tail -f build.log` 跟踪。
4. **镜像/源码权限报错**：到本机 SDK 根目录执行 `sudo chown -R $USER:$USER .`。
5. **不打开多个并行编译**：磁盘 I/O 与内存压力会拖垮整机，逐平台串行。

---

## 引用文档

各平台详细步骤、常见问题、修复方案均收录在对应 `build_*_script.md` 中。本 Skill 只提供"选择 + 快捷"层级的引导，遇到细节请直接读取对应平台文档。

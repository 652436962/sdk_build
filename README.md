# tronlong SDK 目录结构说明

我的主机

lechi@lechi-PC:~$ pwd
/home/lechi

SDK 根路径：`/media/lechi/linuxsdk/linuxsdk`

## 目录树（-L2）

```
/media/lechi/linuxsdk/linuxsdk
├── README.md                         # 本文件：SDK 目录结构说明
├── build_ok3568_script.md            # RK3568 Buildroot SDK Docker 编译环境完整文档
├── build_rk3562_script.md            # RK3562 SDK Docker 编译环境完整文档
├── build_T113i_script.md             # T113i SDK Docker 编译环境完整文档
├── build_T527_script.md              # T527 Linux SDK Docker 编译环境完整文档
├── build_T527_openharmony_script.md  # T527 OpenHarmony 5.0 SDK Docker 编译环境完整文档
├── rk3562_sdk/                       # RK3562 SDK 根目录
│   ├── Lechi/                        # 自定义测试与调试脚本目录
│   ├── hardware_peripherals.md       # RK3562 外设硬件说明
│   ├── ubuntu/                       # Ubuntu 编译相关目录（含 Kernel、U-boot、rootfs 等）
│   └── build_all.log                 # 整体编译日志
├── rk3568_sdk/                       # RK3568 Buildroot SDK 根目录
│   ├── 源码/                          # RK3568 源码目录
│   └── OK3568-linux-source/          # RK3568 Linux 内核源码
├── openharmony_T527/                 # T527 OpenHarmony 5.0 SDK 根目录
│   ├── forlinx-5.0-release/          # 飞凌 T527 OpenHarmony 发布版本（实际编译工作目录）
│   ├── openharmony_prebuilts/        # OpenHarmony 预编译工具链
│   └── 飞凌板级支持包/                  # 飞凌 T527 BSP 资料
├── tina5.0_v2.5/                     # T113i Tina Linux SDK 根目录
│   ├── tina5.0_v1.0/                 # Tina 5.0 SDK 解压目录（实际编译工作目录）
│   ├── dl.tar.gz                     # buildroot 下载缓存包
│   ├── LinuxSDK-v2.1.tar.gz          # Linux SDK 归档包
│   ├── tina5.0_fh_v1.0.tar.gz        # Tina 5.0 归档包
│   ├── tina5.0_v1.0_2026-2-26.tar.gz # Tina SDK 带日期归档包
│   ├── build.log                     # 编译日志
│   └── install_deps.log              # 依赖安装日志
├── 原厂编译文档/                        # 各平台原厂/工具使用文档
│   ├── OK527.md                      # 飞凌 OK527 原厂编译文档
│   ├── OpenixCLI_Tutorial.md         # OpenixCLI 全志烧录工具使用说明
│   ├── upgrade_tool_Tutorial.md      # Rockchip upgrade_tool 烧录工具使用说明
│   ├── HDC_INSTALL.md                # HDC 工具安装说明（OpenHarmony）
│   └── build_rk3562_commands.md      # RK3562 常用编译命令速查
├── 模块/                               # 外设模块驱动与适配文档
│   ├── aic8800/                      # AIC8800 WiFi/蓝牙驱动文档
│   ├── ch340/                        # CH340/CH341 USB 转串口驱动
│   ├── opT527_4g.md                  # T527 4G 模块适配文档
│   └── oprk3568_4g.md                # RK3568 4G 模块适配文档
├── skills/                            # Qoder 自定义 Skill 目录
│   └── build-sdk/                    # SDK 编译相关 Skill
├── .qoder/                            # Qoder IDE 配置目录
├── rk3562_sdk.tar.gz                 # RK3562 SDK 完整归档
├── rk3562_sdk.zip                    # RK3562 SDK 压缩包（备份）
└── tina5.0_v2.5.tar.gz               # T113i SDK 完整压缩包（备份）
```

---

## 各目录用途说明

### RK3562 相关
| 路径 | 说明 |
|------|------|
| `/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/` | RK3562 SDK 根目录，挂载至 Docker 容器 `/workspace` |
| `/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/` | 包含 Kernel、U-boot、rootfs、build.sh 等编译核心文件 |
| `/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/Lechi/` | 自定义测试/调试脚本及资料 |
| `/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/hardware_peripherals.md` | RK3562 外设硬件说明文档 |
| `/media/lechi/linuxsdk/linuxsdk/build_rk3562_script.md` | RK3562 完整编译流程文档（Docker Ubuntu 20.04） |
| `/media/lechi/linuxsdk/linuxsdk/原厂编译文档/build_rk3562_commands.md` | RK3562 编译命令速查手册 |

### RK3568 Buildroot 相关
| 路径 | 说明 |
|------|------|
| `/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/` | RK3568 Buildroot SDK 根目录，挂载至 Docker 容器 `/workspace` |
| `/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/源码/` | RK3568 源码目录 |
| `/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/` | RK3568 Linux 内核源码 |
| `/media/lechi/linuxsdk/linuxsdk/build_ok3568_script.md` | RK3568 Buildroot 完整编译流程文档（Docker Ubuntu 20.04） |

### T527 OpenHarmony 相关
| 路径 | 说明 |
|------|------|
| `/media/lechi/linuxsdk/linuxsdk/openharmony_T527/` | T527 OpenHarmony 5.0 SDK 根目录，挂载至 Docker 容器 `/workspace` |
| `/media/lechi/linuxsdk/linuxsdk/openharmony_T527/forlinx-5.0-release/` | 飞凌 T527 OpenHarmony 发布版本（实际编译工作目录） |
| `/media/lechi/linuxsdk/linuxsdk/openharmony_T527/openharmony_prebuilts/` | OpenHarmony 预编译工具链 |
| `/media/lechi/linuxsdk/linuxsdk/openharmony_T527/飞凌板级支持包/` | 飞凌 T527 BSP 参考资料 |
| `/media/lechi/linuxsdk/linuxsdk/build_T527_openharmony_script.md` | T527 OpenHarmony 5.0 完整编译流程文档（Docker OpenHarmony 3.2） |
| `/media/lechi/linuxsdk/linuxsdk/build_T527_script.md` | T527 Linux SDK 编译流程文档 |
| `/media/lechi/linuxsdk/linuxsdk/原厂编译文档/OK527.md` | 飞凌 OK527 原厂编译/使用文档 |

### T113i 相关
| 路径 | 说明 |
|------|------|
| `/media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5/` | T113i SDK 根目录，挂载至 Docker 容器 `/workspace` |
| `/media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5/tina5.0_v1.0/` | Tina SDK 实际编译工作目录，执行 `source build/envsetup.sh` 的位置 |
| `/media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5/dl.tar.gz` | buildroot 依赖包缓存，可加速离线编译 |
| `/media/lechi/linuxsdk/linuxsdk/build_T113i_script.md` | T113i 完整编译流程文档（Docker Ubuntu 18.04） |

### 外设模块相关
| 路径 | 说明 |
|------|------|
| `/media/lechi/linuxsdk/linuxsdk/模块/aic8800/` | AIC8800 WiFi/蓝牙驱动编译与部署指南 |
| `/media/lechi/linuxsdk/linuxsdk/模块/ch340/CH341SER_LINUX/` | CH340/CH341 USB 转串口 Linux 驱动源码 |
| `/media/lechi/linuxsdk/linuxsdk/模块/opT527_4g.md` | T527 4G 模块适配文档 |
| `/media/lechi/linuxsdk/linuxsdk/模块/oprk3568_4g.md` | RK3568 4G 模块适配文档 |

### 烧录与工具文档
| 路径 | 说明 |
|------|------|
| `/media/lechi/linuxsdk/linuxsdk/原厂编译文档/OpenixCLI_Tutorial.md` | OpenixCLI 全志烧录工具使用说明 |
| `/media/lechi/linuxsdk/linuxsdk/原厂编译文档/upgrade_tool_Tutorial.md` | Rockchip upgrade_tool 烧录工具使用说明 |
| `/media/lechi/linuxsdk/linuxsdk/原厂编译文档/HDC_INSTALL.md` | OpenHarmony HDC 调试工具安装说明 |

### Qoder 辅助目录
| 路径 | 说明 |
|------|------|
| `/media/lechi/linuxsdk/linuxsdk/skills/build-sdk/` | SDK 编译相关自定义 Skill |
| `/media/lechi/linuxsdk/linuxsdk/.qoder/` | Qoder IDE 工程配置目录 |

---

## Docker 容器对应关系

| 容器名 | 基础镜像 | 挂载目录 | 对应平台 |
|--------|----------|----------|----------|
| `rk3568_sdk` | `ubuntu:20.04` | `/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/` → `/workspace` | 瑞芯微 RK3568 Buildroot |
| `rk3562-sdk` | `ubuntu:20.04` | `/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/` → `/workspace` | 瑞芯微 RK3562 |
| `t527-oh5.0` | `openharmony:3.2` | `/media/lechi/linuxsdk/linuxsdk/openharmony_T527/` → `/workspace` | 全志 T527 OpenHarmony |
| `t113i-sdk` | `ubuntu:18.04` | `/media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5/` → `/workspace` | 全志 T113i |

---

## 快速进入编译环境

### RK3568 Buildroot
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3568_sdk
docker start rk3568_sdk
docker exec -it rk3568_sdk /bin/bash
cd /workspace
./build.sh
```

### RK3562
```bash
cd /media/lechi/linuxsdk/linuxsdk/rk3562_sdk
docker start rk3562-sdk
docker exec -it rk3562-sdk /bin/bash
cd /workspace/ubuntu/
```

### T527 OpenHarmony 5.0
```bash
cd /media/lechi/linuxsdk/linuxsdk/openharmony_T527
docker start t527-oh5.0
docker exec -it t527-oh5.0 /bin/bash
cd /workspace/forlinx-5.0-release
./build.sh --product-name okt527 --ccache
```

### T113i
```bash
cd /media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5
docker start t113i-sdk
docker exec -it t113i-sdk /bin/bash
# 进入后
cd /workspace/tina5.0_v1.0
source build/envsetup.sh
```

---

## Qoder Skill 使用说明

本工程已内置 `build-sdk` Skill，位于 [skills/build-sdk/SKILL.md](skills/build-sdk/SKILL.md)，用于在 Qoder IDE 中快速引导多平台 SDK 编译。

### 可用 Skill 一览

| Skill 名称 | 路径 | 作用 |
|------------|------|------|
| `build-sdk` | `skills/build-sdk/SKILL.md` | SDK 编译任务选择器，覆盖 T527 / T527 OH5.0 / T113i / RK3562 / RK3568 五个平台的 Docker 容器启动、SDK 编译与固件打包流程 |

### 触发方式

在 Qoder 对话框直接向 Agent 说出以下任一意图，即会自动匹配并调用 `build-sdk` Skill：

- 「编译 SDK」/「编译固件」/「build sdk」/「build firmware」
- 「开始编译」/「重新编译」/「全量编译」
- 「打包固件」/「生成镜像」/「出刷机包」
- 直接提到具体平台并要求构建，如：「编译 T527 OpenHarmony」、「打包 RK3562 镜像」、「build T113i」

也可以使用斜杠命令显式触发：`/build-sdk`。

### 工作流程（由 Skill 自动执行）

1. **识别目标平台** —— 未指定平台时会弹出选择交互（T527 / T527 OH5.0 / T113i / RK3562 / RK3568）
2. **读取对应 `build_*_script.md` 文档** —— 所有细节步骤以该文档为准
3. **环境检查三连** —— 容器是否存在、SDK 目录权限、是否需要 `chown`
4. **按文档执行编译** —— 推荐 `docker exec -d ... | tee build.log` 后台运行

### 编译输出路径速查

| 平台 | 主固件 | 打包输出 |
|------|--------|----------|
| T527 (Linux) | `out/t527_linux_okt527_uart0.img` | `out/pack_out/` |
| T527 (OH5.0) | `out/pack_out/okt527_uart0.img` | `out/pack_out/` |
| T113i | `out/t113i_uart0.img` | `out/pack_out/` |
| RK3562 | `ubuntu/rockchip/output/update/Image/update.img` | - |
| RK3568 | `OK3568-linux-source/output/` | - |

### 使用注意事项

1. 首次编译 OpenHarmony 必须先执行 `bash build/prebuilts_download.sh`（约 10 GB 下载），否则 `build.sh` 立即报错。
2. 容器名区分平台：T527 OH5.0 用 `okt527-oh5.0`，T113i 用 `t113i`，RK3562 用 `rk3562`，RK3568 用 `ok3568`。
3. 长任务建议用 `docker exec -d <name> bash -c "cmd 2>&1 | tee build.log"` 后台执行，再 `tail -f build.log` 跟踪。
4. 遇源码/镜像权限报错，到本机 SDK 根目录执行 `sudo chown -R $USER:$USER .`。
5. 避免多个平台并行编译，磁盘 I/O 与内存压力会拖垮整机，请逐平台串行。

> 详细步骤、常见问题与修复方案请参阅 [skills/build-sdk/SKILL.md](skills/build-sdk/SKILL.md) 以及各平台 `build_*_script.md` 文档。

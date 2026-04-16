# tronlong SDK 目录结构说明

主机

lechi@lechi-PC:~$ pwd
/home/lechi


## 目录树（-L2）

```
tronlong
├── build_ok3568_script.md           # RK3568 Buildroot SDK Docker 编译环境完整文档
├── build_rk3562_commands.md         # RK3562 常用编译命令速查
├── build_rk3562_script.md           # RK3562 SDK Docker 编译环境完整文档
├── build_T113i_script.md            # T113i SDK Docker 编译环境完整文档
├── build_T527_openharmony_script.md # T527 OpenHarmony 5.0 SDK Docker 编译环境完整文档
├── sdk_tree.md                      # 本文件：SDK 目录结构说明
├── rk3562_sdk                       # RK3562 SDK 根目录
│   ├── init.sh                      # 初始化脚本
│   └── ubuntu                       # Ubuntu 编译相关目录（含 Kernel、U-boot、rootfs 等）
├── rk3562_sdk.zip                   # RK3562 SDK 压缩包（备份）
├── RK3568_sdk                       # RK3568 Buildroot SDK 根目录
│   └── ubuntu                       # Ubuntu 编译相关目录
├── t527_openharmony                 # T527 OpenHarmony 5.0 SDK 根目录
├── tina5.0_v2.5                     # T113i Tina Linux SDK 根目录
│   ├── dl.tar.gz                    # buildroot 下载缓存包
│   ├── LinuxSDK-v2.1.tar.gz         # Linux SDK 归档包
│   ├── tina5.0_fh_v1.0.tar.gz       # Tina 5.0 归档包
│   ├── tina5.0_v1.0                 # Tina 5.0 SDK 解压目录（实际编译工作目录）
│   └── tina5.0_v1.0_2026-2-26.tar.gz # Tina SDK 带日期归档包
└── tina5.0_v2.5.tar.gz              # T113i SDK 完整压缩包（备份）
```

---

## 各目录用途说明

### RK3562 相关
| 路径 | 说明 |
|------|------|
| `rk3562_sdk/` | RK3562 SDK 根目录，挂载至 Docker 容器 `/workspace` |
| `rk3562_sdk/ubuntu/` | 包含 Kernel、U-boot、rootfs、build.sh 等编译核心文件 |
| `rk3562_sdk/init.sh` | SDK 初始化脚本 |
| `build_rk3562_script.md` | RK3562 完整编译流程文档（Docker Ubuntu 20.04） |
| `build_rk3562_commands.md` | RK3562 编译命令速查手册 |

### RK3568 Buildroot 相关
| 路径 | 说明 |
|------|------|
| `RK3568_sdk/` | RK3568 Buildroot SDK 根目录，挂载至 Docker 容器 `/workspace` |
| `RK3568_sdk/ubuntu/` | 包含 Kernel、U-boot、rootfs、build.sh 等编译核心文件 |
| `build_ok3568_script.md` | RK3568 Buildroot 完整编译流程文档（Docker Ubuntu 20.04） |

### T527 OpenHarmony 相关
| 路径 | 说明 |
|------|------|
| `t527_openharmony/` | T527 OpenHarmony 5.0 SDK 根目录，挂载至 Docker 容器 `/workspace` |
| `build_T527_openharmony_script.md` | T527 OpenHarmony 5.0 完整编译流程文档（Docker OpenHarmony 3.2） |

### T113i 相关
| 路径 | 说明 |
|------|------|
| `tina5.0_v2.5/` | T113i SDK 根目录，挂载至 Docker 容器 `/workspace` |
| `tina5.0_v2.5/tina5.0_v1.0/` | Tina SDK 实际编译工作目录，执行 `./build.sh` 的位置 |
| `tina5.0_v2.5/dl.tar.gz` | buildroot 依赖包缓存，可加速离线编译 |
| `build_T113i_script.md` | T113i 完整编译流程文档（Docker Ubuntu 18.04） |

---

## Docker 容器对应关系

| 容器名 | 基础镜像 | 挂载目录 | 对应平台 |
|--------|----------|----------|----------|
| `RK3568_sdk` | `ubuntu:20.04` | `RK3568_sdk/` → `/workspace` | 瑞芯微 RK3568 Buildroot |
| `rk3562-sdk` | `ubuntu:20.04` | `rk3562_sdk/` → `/workspace` | 瑞芯微 RK3562 |
| `t527-oh5.0` | `openharmony:3.2` | `t527_openharmony/` → `/workspace` | 全志 T527 OpenHarmony |
| `t113i-sdk` | `ubuntu:18.04` | `tina5.0_v2.5/` → `/workspace` | 全志 T113i |

---

## 快速进入编译环境

### RK3568 Buildroot
```bash
cd /home/lechi/tronlong/RK3568_sdk
docker start RK3568_sdk
docker exec -it RK3568_sdk /bin/bash
cd /workspace
./build.sh
```

### RK3562
```bash
cd /home/lechi/tronlong/rk3562_sdk
docker start rk3562-sdk
docker exec -it rk3562-sdk /bin/bash
cd rk3562_sdk/ubuntu/
```

### T527 OpenHarmony 5.0
```bash
cd /home/lechi/tronlong/t527_openharmony
docker start t527-oh5.0
docker exec -it t527-oh5.0 /bin/bash
cd /workspace
./build.sh --product-name okt527 --ccache
```

### T113i
```bash
cd /home/lechi/tronlong/tina5.0_v2.5
docker start t113i-sdk
docker exec -it t113i-sdk /bin/bash
# 进入后
cd /workspace/tina5.0_v2.5/tina5.0_v1.0
source build/envsetup.sh
```

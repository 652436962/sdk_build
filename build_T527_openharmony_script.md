# T527 OpenHarmony 5.0 Docker 编译环境完整使用文档
**适用系统**：Ubuntu 18.04 / 20.04 / 22.04
**适用平台**：全志 T527 系列开发板（飞凌 OK527-C）
**核心优势**：官方 Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

## 前言

本文专为飞凌 OK527-C 开发板的 OpenHarmony 5.0 SDK 编译打造，基于官方 Docker 镜像搭建标准编译环境，完全适配官方编译要求，彻底解决本机编译常见的依赖缺失、权限冲突、工具链版本不兼容等问题。
核心原则：**保留编译环境，避免每次重复安装依赖**，保证编译流程稳定、高效。

---

## 一、前期准备

### 1.1 前提条件
1. 本机系统：Ubuntu 18.04 / 20.04 / 22.04（推荐纯净系统）
2. 飞凌 T527 OpenHarmony 5.0 SDK 已解压完成，**存放路径无中文、空格、特殊字符**
3. 网络正常，可拉取 Docker 镜像

### 1.2 安装 Docker（仅执行一次）
打开终端，逐行执行以下命令，安装并配置 Docker 环境：
```bash
# 刷新软件源
sudo apt update

# 安装 Docker（Ubuntu 18.04/20.04）
sudo apt install docker.io -y

# 安装 Docker（Ubuntu 22.04 及以上）
# sudo apt install docker.io 或 sudo apt install docker-ce

# 设置 Docker 开机自启
sudo systemctl enable docker

# 启动 Docker 服务
sudo systemctl start docker

# 将当前用户加入 docker 组，后续使用免 sudo
sudo usermod -aG docker $USER
```

**关键操作**：执行完成后，**必须注销当前用户并重新登录**，否则 Docker 权限配置不生效。

### 1.3 拉取官方 Docker 镜像
```bash
# 拉取 OpenHarmony 5.0 标准版编译环境镜像
sudo docker pull swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2

# 验证镜像拉取成功
sudo docker images
```

### 1.4 SDK 目录权限修复（仅执行一次）
进入 T527 OpenHarmony SDK 根目录，修复文件权限：
```bash
# 进入 SDK 根目录（替换为你实际的 SDK 路径）
cd /home/lechi/tronlong/t527\ _openharmony/forlinx-5.0-release

# 修复目录归属（推荐）
sudo chown -R $USER:$USER .
```

---

## 二、进入 Docker 编译环境

### 2.1 启动容器命令（首次执行）
**先进入本机 T527 OpenHarmony SDK 根目录**，再执行以下命令，自动进入编译容器：
```bash
cd /home/lechi/tronlong/t527\ _openharmony/forlinx-5.0-release

sudo docker run -it \
--name okt527-oh5.0 \
-v $(pwd):/home/openharmony \
-w /home/openharmony \
swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2 \
/bin/bash
```

> **注意**：此处已移除 `--rm` 参数，用于保留容器环境，避免每次重复拉取镜像。

### 2.2 命令参数说明
| 参数 | 作用 |
|------|------|
| `--name okt527-oh5.0` | 容器命名，区分开发板型号 |
| `-v $(pwd):/home/openharmony` | 本机 SDK 目录映射到容器，文件双向同步 |
| `-w /home/openharmony` | 容器内默认进入 SDK 工作目录 |

### 2.3 重新进入已存在的容器
查看已有容器：
```bash
sudo docker ps -a
```

如果容器已创建（非首次启动），使用以下命令重新进入：
```bash
sudo docker start okt527-oh5.0
sudo docker exec -it okt527-oh5.0 /bin/bash
```

环境就绪标识：终端提示符变为
`root@xxxxx:/home/openharmony#`

---

## 三、SDK 编译指令

在 Docker 容器内，执行以下命令初始化编译环境：

### 3.1 初始化编译环境
```bash
# 进入 SDK 工作目录
cd /home/openharmony

# 检查环境
ls -la build.sh
```

### 3.2 全量编译（推荐，生成完整刷机固件）
```bash
./build.sh --product-name okt527 --ccache
```

### 3.3 单独编译内核
```bash
./build.sh --product-name okt527 --ccache --build-target kernel
```

### 3.4 单独编译子系统
```bash
# 编译内核
./build.sh --product-name okt527 --ccache --build-target kernel

# 编译启动引导
./build.sh --product-name okt527 --ccache --build-target bootloader

# 编译系统组件
./build.sh --product-name okt527 --ccache --build-target apps
```

### 3.5 编译选项说明
| 选项 | 说明 |
|------|------|
| `--product-name` | 产品名称，飞凌 T527 使用 `okt527` |
| `--ccache` | 启用编译缓存，加速重复编译 |
| `--build-target` | 指定编译目标（kernel/bootloader/apps/acts 等） |

编译时长：30~90 分钟（取决于 CPU 核心数与内存）
**固件输出路径**：`out/okt527/packages/phone/images/` 目录

---

## 四、退出与重新进入

### 4.1 退出容器
容器内执行 `exit`，本机 SDK 文件不受影响：
```bash
exit
```

### 4.2 下次编译流程
1. 执行以下命令重新进入已存在的容器：
   ```bash
   sudo docker start okt527-oh5.0
   sudo docker exec -it okt527-oh5.0 /bin/bash
   ```
2. 进入 SDK 目录：
   ```bash
   cd /home/openharmony
   ```
3. 直接执行编译命令，**无需重复拉取镜像**：
   ```bash
   ./build.sh --product-name okt527 --ccache
   ```

---

## 五、常见问题与修复

### 5.1 Docker 拉取镜像失败
**现象**：
```
Error response from daemon: Get https://swr.cn-south-1.myhuaweicloud.com/...: dial tcp: lookup swr.cn-south-1.myhuaweicloud.com: no such host
```

**修复方法**：
```bash
# 配置 Docker 镜像加速（国内服务器推荐）
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://ccr.ccs.tencentyun.com/",
    "https://docker.mirrors.ustc.edu.cn/",
    "https://hub-mirror.c.163.com/"
  ]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 5.2 权限问题
**现象**：
```
permission denied
```

**修复方法**（本机执行）：
```bash
cd /home/lechi/tronlong/t527\ _openharmony/forlinx-5.0-release
sudo chown -R $USER:$USER .
```

### 5.3 编译卡住或内存不足
**现象**：编译过程中系统变卡或崩溃

**修复方法**：
```bash
# 限制 Docker 容器内存使用
docker run -it --memory=8g ...
```

### 5.4 编译产物清理
```bash
# 清理编译产物（保留源码）
rm -rf out/

# 清理编译缓存
rm -rf ~/.cache/build
```

---

## 六、容器时区设置（可选）

如需将容器时区设置为北京时间（Asia/Shanghai），在容器内执行：
```bash
# 安装时区数据（如未安装）
apt-get update && apt-get install -y tzdata

# 设置时区为上海
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# 验证
date
```

---

## 七、注意事项

1. SDK 存放路径**严禁包含中文、空格、特殊字符**，否则直接编译失败
2. 编译过程中**不要关闭终端、不要中断进程**，否则固件损坏
3. 如需彻底删除容器重建环境，执行：
   ```bash
   sudo docker stop okt527-oh5.0 && sudo docker rm okt527-oh5.0
   ```
4. 首次拉取镜像耗时较长，请耐心等待
5. 每次进入容器后，必须先进入 SDK 目录 `cd /home/openharmony`

---

## 快捷操作总结（一键记忆）

### 首次使用（创建容器并进入）
```bash
# 1. 进入 SDK 目录
cd /home/lechi/tronlong/t527\ _openharmony/forlinx-5.0-release

# 2. 拉取官方 Docker 镜像（如未拉取）
sudo docker pull swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2

# 3. 启动容器（首次创建）
sudo docker run -it --name okt527-oh5.0 -v $(pwd):/home/openharmony -w /home/openharmony swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2 /bin/bash

# 4. 在容器内执行编译
cd /home/openharmony
./build.sh --product-name okt527 --ccache

# 5. 退出
exit
```

### 后续使用（直接进入已存在容器）
```bash
# 1. 进入 SDK 目录
cd /home/lechi/tronlong/t527\ _openharmony/forlinx-5.0-release

# 2. 启动已存在的容器
sudo docker start okt527-oh5.0

# 3. 进入容器
sudo docker exec -it okt527-oh5.0 /bin/bash

# 4. 进入 SDK 目录并编译
cd /home/openharmony
./build.sh --product-name okt527 --ccache

# 5. 退出
exit
```

---

## 相关资源

- **OpenHarmony 官方文档**：https://gitee.com/openharmony/docs
- **飞凌嵌入式**：https://www.forlinx.com
- **Docker 镜像仓库**：swr.cn-south-1.myhuaweicloud.com/openharmony-docker/

---

**备注**：本文档适配飞凌 OK527-C 开发板的 OpenHarmony 5.0 SDK，Docker 编译环境基于官方标准镜像，与官方编译要求一致。
固件烧录工具推荐使用官方工具（详情请参考飞凌提供的烧录文档）。
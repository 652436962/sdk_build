# Deepin 安装 Docker 完整文档

**适用系统**：Deepin 25（版本代号 `crimson`）、Deepin 23 / 20.9 参考可用
**用途**：为本仓库各平台 SDK（T527 / T113i / RK3562 / RK3568 等）搭建 Docker 编译环境
**核心优势**：Docker 隔离环境，不污染本机系统，无依赖冲突、版本兼容问题，编译环境稳定纯净。

> 本文档中标注「本机实测」的内容，均已在当前主机（Deepin 25, 内核 6.18.48, Docker CE 26.1.4）验证通过。

---

## 一、背景说明

Docker 官方**没有提供 deepin 软件源**（只有 Ubuntu / Debian / CentOS / Fedora / RHEL 等）。在 Deepin 上安装 Docker 有两条可行路线：

| 方案 | 软件源 | 版本情况 | 说明 |
|------|--------|----------|------|
| **方案 A：官方 docker-ce 源（Debian 仓库）** | `download.docker.com/linux/debian` | 本机实测 26.1.4 | 版本新、组件全（含 compose、buildx），**本仓库当前环境采用此方案** |
| **方案 B：deepin 社区仓库** | `community-packages.deepin.com` | 26.1.5 | 一条命令最省事，缺点是版本跟随发行版、更新滞后 |

两条路线**只能选一条**，混装会导致 apt 依赖冲突。

**实测环境信息（当前主机）**

```
操作系统 : Deepin 25 (crimson)
内核     : 6.18.48-amd64-desktop-rolling
glibc    : 2.38
Docker   : docker-ce 26.1.4（来自 debian buster 源）
运行时   : containerd.io 1.6.33
Compose  : docker compose v2.27.1（插件形式，无 docker-compose 独立命令）
存储驱动 : overlay2（extfs）
cgroup   : v2 / systemd 驱动
iptables : v1.8.11 (nf_tables)
```

---

## 二、方案 A：安装官方 Docker CE（推荐，本机实测）

### 2.1 前置检查

```bash
# 查看系统版本与代号
cat /etc/os-release

# 查看 glibc 版本（决定可选哪个 Debian 仓库，见 2.3 说明）
ldd --version | head -1

# 若之前装过 deepin 仓库的 docker.io，先卸载干净，避免冲突
sudo apt remove -y docker.io docker-compose docker-doc podman-docker containerd runc
```

### 2.2 安装步骤（逐行执行）

```bash
# 1、安装基础依赖
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# 2、创建密钥目录并导入 Docker 官方 GPG 公钥
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg
sudo chmod a+r /etc/apt/keyrings/docker-archive-keyring.gpg

# 3、写入软件源（关键：使用 Debian 仓库，因为 Docker 无 deepin 源）
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/debian buster stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list

# 4、刷新源并查看可安装版本（确认没有报 GPG / 404 错误）
sudo apt update
apt policy docker-ce

# 5、安装 Docker 全套组件
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# 6、设置开机自启并立即启动
sudo systemctl enable docker
sudo systemctl start docker

# 7、将当前用户加入 docker 组，后续使用免 sudo
sudo usermod -aG docker $USER
```

**关键操作**：执行完成后，**必须注销当前用户并重新登录**（或重启），否则 docker 组权限不生效。

> 本机实际结果：`docker.list` 指向 `... linux/debian buster stable`，安装得到 `docker-ce 5:26.1.4-1~debian.10~buster`，用户 `lechi` 已加入 `docker` 组（gid 986）。

### 2.3 关于 Debian 仓库代号（buster / bookworm）的选择

- `buster`（Debian 10）：兼容性最好，几乎任何 deepin 版本都能装，但**版本停在 26.1.4**（buster 源已不再更新），本机即采用此项。
- `bookworm`（Debian 12）：版本更新，但要求 glibc ≥ 2.36。本机 glibc 为 **2.38**，理论上可切换，若需要更新的 Docker 版本可改用：

```bash
# 可选：切换到 bookworm 源（本机未实测，切换后若报依赖错误，改回 buster 即可）
sudo sed -i 's/debian buster stable/debian bookworm stable/' /etc/apt/sources.list.d/docker.list
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

---

## 三、方案 B：使用 deepin 社区仓库安装（最简）

适合只需要一个能跑的 Docker、不追求最新版本的场景：

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

当前 Deepin 25 仓库中 `docker.io` 候选版本为 **26.1.5+dfsg1-4**。

注意：

- 该方式**不含** `docker compose` V2 插件，deepin 仓库里只有老旧的 `docker-compose`（候选版本 1.29.2，即 V1），需要 `docker compose` 子命令时建议改用方案 A。
- 与方案 A 的 `docker-ce` **互斥**，不能混装。

---

## 四、安装后配置（两种方案通用）

### 4.1 配置镜像加速（国内拉取必备）

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": ["https://ccr.ccs.tencentyun.com/"]
}
EOF

# 重载配置并重启
sudo systemctl daemon-reload
sudo systemctl restart docker
```

本机 `/etc/docker/daemon.json` 即为上述内容，`docker info` 的 `Registry Mirrors` 已生效。
可追加的备用镜像：`https://docker.m.daocloud.io`、`https://mirror.ccs.tencentyun.com`。

### 4.2 免 sudo 使用 docker

```bash
# 确认已加入 docker 组
getent group docker
id $USER

# 若未生效，手动加入并重新登录
sudo usermod -aG docker $USER
# 免注销的临时方案（仅当前终端有效）
newgrp docker
```

> docker 组等价于 root 权限，仅建议在个人开发机上使用。

### 4.3 迁移 Docker 数据目录（SDK 编译占空间较大，可选）

SDK 编译镜像与容器容易占满系统盘，可将数据目录迁到数据盘：

```bash
sudo systemctl stop docker
sudo mkdir -p /media/lechi/linuxsdk/docker-data

# 修改 daemon.json，加入 data-root
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": ["https://ccr.ccs.tencentyun.com/"],
  "data-root": "/media/lechi/linuxsdk/docker-data"
}
EOF

# 迁移已有数据（如无需保留可跳过）
sudo rsync -aP /var/lib/docker/ /media/lechi/linuxsdk/docker-data/

sudo systemctl daemon-reload
sudo systemctl start docker
docker info | grep "Docker Root Dir"
```

---

## 五、验证安装

```bash
# 1、版本信息
docker --version
docker compose version

# 2、服务端信息（重点看 Storage Driver / Cgroup / Registry Mirrors）
docker info

# 3、跑一个测试容器
docker run --rm hello-world

# 4、免 sudo 验证（重新登录后执行，能列出容器即成功）
docker ps
```

本机 `docker info` 关键输出：

```
Server Version   : 26.1.4
Storage Driver   : overlay2 (Backing Filesystem: extfs)
Cgroup Driver    : systemd  (Cgroup Version: 2)
Docker Root Dir  : /var/lib/docker
Registry Mirrors : https://ccr.ccs.tencentyun.com/
Operating System : Deepin 25
```

---

## 六、与本仓库 SDK 编译环境的衔接

安装 Docker 只是第一步，各平台编译还需创建/进入对应容器（详见各 `build_*_script.md`）：

| 平台 | 容器名 | 挂载点 | 基础镜像 |
|------|--------|--------|----------|
| T527 Linux | `t527_linuxsdk` | `t527_sdk/` → `/workspace` | `ubuntu:20.04` |
| T527 OH5.0 | `t527_openharmony` | `t527_openharmony/` → `/home/openharmony` | `ubuntu:20.04` |
| T113i | `t113i-sdk` | `tina5.0_v2.5/` → `/workspace` | `ubuntu:18.04` |
| RK3562 | `rk3562-sdk` | `rk3562_sdk/` → `/workspace` | `ubuntu:20.04` |
| RK3562 Huayun | `huayun-sdk` | `huayun_sdk/` → `/workspace` | `ubuntu:20.04` |
| RK3568 Buildroot | `rk3568_sdk` | `rk3568_sdk/` → `/workspace` | `ubuntu:20.04` |
| RK3568 Ubuntu | `rk3568_ubuntu` | `rk3568_ubuntu/` → `/workspace` | `ubuntu:22.04` |

**常用操作**：

```bash
# 拉取基础镜像（首次）
docker pull ubuntu:20.04

# 重新进入已存在的容器（不要重复创建）
docker start t527_linuxsdk
docker exec -it t527_linuxsdk /bin/bash

# 查看全部容器状态
docker ps -a

# 长时间编译：后台执行 + 日志跟踪
docker exec -d t527_linuxsdk bash -c "cmd 2>&1 | tee build.log"
docker exec t527_linuxsdk tail -f /workspace/build.log
```

---

## 七、常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| `Cannot connect to the Docker daemon` | 服务未启动 / 用户未刷新组 | `sudo systemctl start docker`；`sudo usermod -aG docker $USER` 后**重新登录** |
| `permission denied ... docker.sock` | 当前用户不在 docker 组 | `getent group docker` 核对，重新加入并重登；临时可用 `sudo docker ...` |
| `docker pull` 超时 / 失败 | 未配镜像加速或网络受限 | 按 4.1 配置 `/etc/docker/daemon.json` 后 `sudo systemctl restart docker` |
| apt 报 GPG 错误 / `NO_PUBKEY` | 公钥未导入或路径不符 | 重新执行 2.2 第 2 步，确认 `signed-by=` 路径与文件名一致 |
| apt 报 docker 包依赖冲突 | `docker.io` 与 `docker-ce` 混装 | 卸载旧包：`sudo apt remove --purge docker.io docker-compose containerd runc` 后重装 |
| `docker-compose: 未找到命令` | Compose V1 已被 V2 插件取代 | 使用 `docker compose ...`（子命令形式），或安装 `docker-compose-plugin` |
| 磁盘占满 / 编译报空间不足 | 镜像与容器全在系统盘 | 迁移 `data-root`（见 4.3），并定期 `docker system prune -a` |
| 容器内编译报权限错误 | 挂载目录属主不是当前用户 | 宿主机 SDK 目录执行 `sudo chown -R $USER:$USER .` |
| 源码路径含中文/空格导致编译异常 | 工具链对路径敏感 | 确认 SDK 绝对路径无中文、空格与特殊字符 |

---

## 八、一键安装脚本（方案 A）

将以下内容保存为 `install_docker_deepin.sh` 并执行 `bash install_docker_deepin.sh`：

```bash
#!/bin/bash
set -e

echo "==> [1/5] 安装基础依赖"
sudo apt update
sudo apt install -y ca-certificates curl gnupg

echo "==> [2/5] 导入 Docker GPG 公钥"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg
sudo chmod a+r /etc/apt/keyrings/docker-archive-keyring.gpg

echo "==> [3/5] 写入软件源"
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/debian buster stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list

sudo apt update

echo "==> [4/5] 安装 Docker"
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

echo "==> [5/5] 启动服务并配置镜像加速"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "registry-mirrors": ["https://ccr.ccs.tencentyun.com/"]
}
EOF
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER"

echo "==> 完成。请注销并重新登录后执行: docker run --rm hello-world"
```

---

## 附：与各平台编译文档的关系

- 本文件只负责**宿主机 Docker 环境**的安装与排错。
- 各平台 SDK 的解压、容器创建、编译命令，请看对应的 `build_*_script.md`：
  `build_T527_linuxsdk_script.md`、`build_T527_ubuntu20_op_script.md`、`build_T113i_script.md`、
  `build_rk3562_script.md`、`build_rk3562_buildroot_script.md`、`build_ok3568_script.md`、
  `build_rk3568_ubuntu22_script.md`、`build_huayun_script.md`。

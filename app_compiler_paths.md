# 各平台应用交叉编译器路径汇总

> 汇总各嵌入式平台 SDK 编译完成后生成的**应用（用户态程序）交叉编译器**路径，供快速配置环境编译应用。
> 依据各 `build_*.md` 文档整理，路径已在宿主机逐一验证（✅ 已生成 / ⏳ 需先编译 SDK）。

| 版本号 | 修改时间   | 修改人 | 修改内容               |
|--------|------------|--------|------------------------|
| V1.0   | 2026-08-17 | lechi  | 初始版本（汇总 8 个平台应用编译器路径） |

---

## 一、总览

| 平台 | SDK 目录 | Docker 容器 | 编译器前缀 | 状态 |
|------|----------|-------------|-----------|------|
| T113i（Tina） | `tina5.0_v2.5/` | `t113i-sdk` | `arm-linux-gnueabi-` | ✅ |
| RK3562 Ubuntu | `rk3562_sdk/` | `rk3562-sdk` | `aarch64-linux-gnu-` | ✅ |
| RK3562 Huayun | `huayun_sdk/` | `huayun-sdk` | `aarch64-linux-gnu-` | ✅ |
| RK3562 Buildroot | `rk3562_buildroot/` | `rk3562_buildroot` | `aarch64-buildroot-linux-gnu-` | ✅ |
| T527 Linux | `t527_sdk/` | `t527_linuxsdk` | `aarch64-none-linux-gnu-` | ✅ |
| T527 OpenHarmony | `openharmony_T527/` | `t527_openharmony` | `clang` / `aarch64-linux-gnu-` | ✅ |
| RK3568 Buildroot | `rk3568_sdk/` | `rk3568_sdk` | `aarch64-linux-` | ⏳ 编译后生成 |
| RK3568 Ubuntu | `rk3568_ubuntu/` | `rk3568_ubuntu` | `aarch64-linux-gnu-` | ⏳ 编译后生成 |

> 说明：编译一律在 Docker 容器内执行，容器内 SDK 挂载点为 `/workspace`（T527 OpenHarmony 为 `/home/openharmony`）。

---

## 二、T113i（全志 Tina Linux）

- **容器**：`t113i-sdk`，SDK 挂载：`tina5.0_v2.5/` → `/workspace`
- **编译器**：`arm-linux-gnueabi-gcc`（Linaro GCC 7.3-2018.05，ARMv7-A 32 位软浮点）

**宿主机路径**（已验证 ✅）：
```
/media/lechi/linuxsdk/linuxsdk/tina5.0_v2.5/tina5.0_v1.0/out/t113_i/tlt113-evm-emmc/buildroot/buildroot/host/bin/
```

**容器内路径**：
```
/workspace/tina5.0_v1.0/out/t113_i/tlt113-evm-emmc/buildroot/buildroot/host/bin/
```

**环境配置**（容器内执行）：
```bash
export PATH=/workspace/tina5.0_v1.0/out/t113_i/tlt113-evm-emmc/buildroot/buildroot/host/bin:$PATH
export STAGING_DIR=/workspace/tina5.0_v1.0/out/t113_i/tlt113-evm-emmc/buildroot/buildroot/host/arm-buildroot-linux-gnueabi/sysroot
arm-linux-gnueabi-gcc --version
```

---

## 三、RK3562 Ubuntu（rk3562_sdk）

- **容器**：`rk3562-sdk`，SDK 挂载：`rk3562_sdk/` → `/workspace`
- **编译器**：`aarch64-linux-gnu-gcc`（GCC Linaro 10.2.1，AArch64）

**环境文件**（已验证 ✅，source 后自动设置 `CC/CXX/AR/...`）：
```
/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/environment
```

**工具链路径**（含在 environment 中）：
```
/media/lechi/linuxsdk/linuxsdk/rk3562_sdk/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/sysroots/x86_64-linux/bin/gcc-linaro-10.2.1-2021.01-x86_64_aarch64-linux-gnu/bin/
```

**环境配置**（容器内执行）：
```bash
source /workspace/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/environment
make CC=aarch64-linux-gnu-gcc
```

---

## 四、RK3562 Huayun（huayun_sdk）

- **容器**：`huayun-sdk`，SDK 挂载：`huayun_sdk/` → `/workspace`
- **编译器**：`aarch64-linux-gnu-gcc`（GCC Linaro 10.2.1，AArch64）
- 工具链与 RK3562 Ubuntu 同版本，SDK 分支自 `rk3562_sdk`，仅路径前缀不同

**环境文件**（已验证 ✅）：
```
/media/lechi/linuxsdk/linuxsdk/huayun_sdk/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/environment
```

**环境配置**（容器内执行）：
```bash
source /workspace/ubuntu/rk3562-ubuntu20.04-sdk/rk3562-ubuntu20.04-sdk-v1.0/environment
make CC=aarch64-linux-gnu-gcc
```

---

## 五、RK3562 Buildroot（rk3562_buildroot）

- **容器**：`rk3562_buildroot`，SDK 挂载：`rk3562_buildroot/` → `/workspace`
- **编译器**：`aarch64-buildroot-linux-gnu-gcc`（需先编译 Buildroot 生成）

**宿主机路径**（已验证 ✅）：
```
/media/lechi/linuxsdk/linuxsdk/rk3562_buildroot/rk3562_linux_sdk_release/buildroot/output/rockchip_rk3562/host/bin/
```

**容器内路径**：
```
/workspace/buildroot/output/rockchip_rk3562/host/bin/
```

**环境配置**（容器内执行）：
```bash
source /workspace/buildroot/output/rockchip_rk3562/host/environment-setup
```

---

## 六、T527 Linux（t527_sdk）

- **容器**：`t527_linuxsdk`，SDK 挂载：`t527_sdk/` → `/workspace`
- **编译器**：`aarch64-none-linux-gnu-gcc`（GCC ARM 10.3，AArch64）

**宿主机路径**（已验证 ✅）：
```
/media/lechi/linuxsdk/linuxsdk/t527_sdk/OKT527-linux-sdk/out/t527/okt527/buildroot/buildroot/host/bin/
```

**容器内路径**：
```
/workspace/OKT527-linux-sdk/out/t527/okt527/buildroot/buildroot/host/bin/
```

**环境配置**（容器内执行）：
```bash
export PATH=/workspace/OKT527-linux-sdk/out/t527/okt527/buildroot/buildroot/host/bin:$PATH
aarch64-none-linux-gnu-gcc --version
```

---

## 七、T527 OpenHarmony（openharmony_T527）

- **容器**：`t527_openharmony`，SDK 挂载：`openharmony_T527/forlinx-5.0-release/` → `/home/openharmony`
- **编译器**：官方推荐 `clang`（prebuilts，已验证 ✅）；内核/驱动可用 `aarch64-linux-gnu-gcc`（已验证 ✅）

**clang 路径（容器内）**：
```
/home/openharmony/forlinx-5.0-release/prebuilts/clang/ohos/linux-x86_64/llvm/bin/clang
```

**gcc 路径（容器内）**：
```
/home/openharmony/forlinx-5.0-release/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu/bin/
```

**环境配置**（容器内执行）：
```bash
export PATH=/home/openharmony/forlinx-5.0-release/prebuilts/clang/ohos/linux-x86_64/llvm/bin:$PATH
clang --version
```

---

## 八、RK3568 Buildroot（rk3568_sdk）

- **容器**：`rk3568_sdk`，SDK 挂载：`rk3568_sdk/` → `/workspace`
- **编译器**：`aarch64-linux-gcc`（Buildroot 生成，需先执行 `./build.sh` 编译）

**容器内路径**（⏳ 编译后生成）：
```
/workspace/OK3568-linux-source/buildroot/output/OK3568/host/bin/
```

**宿主机路径**：
```
/media/lechi/linuxsdk/linuxsdk/rk3568_sdk/OK3568-linux-source/buildroot/output/OK3568/host/bin/
```

**环境配置**（容器内执行）：
```bash
export PATH=/workspace/OK3568-linux-source/buildroot/output/OK3568/host/bin:$PATH
aarch64-linux-gcc --version
```

---

## 九、RK3568 Ubuntu（rk3568_ubuntu）

- **容器**：`rk3568_ubuntu`，SDK 挂载：`rk3568_ubuntu/` → `/workspace`
- **编译器**：系统包 `aarch64-linux-gnu-gcc`（Ubuntu 22.04 apt 安装，容器内 `/usr/bin/`）；应用编译链（QT 等）为 Buildroot 生成链（⏳ 编译后生成）

**系统包工具链（容器内，随依赖安装）**：
```
/usr/bin/aarch64-linux-gnu-gcc
```

**Buildroot 应用编译链（容器内，⏳ 编译后生成）**：
```
/workspace/OK3568-linux-source/buildroot/output/OK3568/host/bin/
```

**环境配置**（容器内执行）：
```bash
# 方式一：系统包工具链
aarch64-linux-gnu-gcc --version

# 方式二：Buildroot 编译链（编译后）
export PATH=/workspace/OK3568-linux-source/buildroot/output/OK3568/host/bin:$PATH
```

---

## 十、编译示例（通用）

```bash
# 以 T527 Linux 为例，其余平台替换 PATH 即可
export PATH=/workspace/OKT527-linux-sdk/out/t527/okt527/buildroot/buildroot/host/bin:$PATH

# 编写测试程序
cat > hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("hello\n"); return 0; }
EOF

# 交叉编译
aarch64-none-linux-gnu-gcc -o hello hello.c
file hello   # 预期：ELF 64-bit LSB ... ARM aarch64
```

---

## 备注

1. 内核 / U-Boot 编译链与**应用编译链不同**，本表仅汇总应用（用户态）编译器；内核链见各 `build_*.md` 文档。
2. Buildroot 类平台（RK3562 Buildroot / T527 / RK3568）的编译链在 SDK 首次全量编译后才生成。
3. T113i 应用编译器在 `out/` 目录下生成，位置随板级配置（`tlt113-evm-emmc`）变化。

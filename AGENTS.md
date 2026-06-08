# AGENTS.md

This is a **multi-platform embedded SDK build orchestration repo**. Actual SDK source code is gitignored — this repo contains only build scripts, documentation, skills, and peripheral module docs.

## Repository structure

- **5 embedded platforms** with Docker-based compilation:
  - T527 Linux (`t527_sdk/`) — container `t527_linuxsdk`, Allwinner, buildroot
  - T527 OpenHarmony 5.0 (`t527_openharmony/`, `openharmony_T527/`) — container `t527_openharmony`
  - T113i (`tina5.0_v2.5/`) — container `t113i-sdk`, Allwinner Tina Linux
  - RK3562 (`rk3562_sdk/`) — container `rk3562-sdk`, Rockchip
  - RK3568 (`rk3568_sdk/`) — container `rk3568_sdk`, Rockchip buildroot

- **Build documentation** (`build_*_script.md`) is the executable source of truth for each platform — always read before executing.
- **Build skill**: `skills/build-sdk/SKILL.md` — Qoder skill for guided multi-platform compilation.
- **Peripheral modules**: `模块/` contains driver docs for WiFi/BT, 4G, GPIO expanders, USB serial.
- **Vendor docs**: `原厂编译文档/` contains flashing tool guides and board-specific docs.

## Critical rules

### All compilation runs inside Docker containers, never on the host

Container ↔ platform mapping (exact names matter):

| Platform | Container name | Mount point | Docker base |
|----------|---------------|-------------|-------------|
| T527 Linux | `t527_linuxsdk` | `t527_sdk/` → `/workspace` | `ubuntu:20.04` |
| T527 OH5.0 | `t527_openharmony` | `t527_openharmony/` → `/home/openharmony` | `ubuntu:20.04` |
| T113i | `t113i-sdk` | `tina5.0_v2.5/` → `/workspace` | `ubuntu:18.04` |
| RK3562 | `rk3562-sdk` | `rk3562_sdk/` → `/workspace` | `ubuntu:20.04` |
| RK3568 | `rk3568_sdk` | `rk3568_sdk/` → `/workspace` | `ubuntu:20.04` |

### Re-enter existing containers (never recreate)

```bash
docker start <container-name>
docker exec -it <container-name> /bin/bash
```

### Long builds: use background exec + log tail

```bash
docker exec -d <name> bash -c "cmd 2>&1 | tee build.log"
docker exec <name> tail -f <path>/build.log
```

### Do NOT modify SDK source dirs

All SDK source directories (`t527_sdk/`, `t527_openharmony/`, `rk3562_sdk/`, `rk3568_sdk/`, `openharmony_T527/`, `tina5.0_v2.5/`) are in `.gitignore`. Changes to them are not versioned and not part of this repo. Only work with files tracked by git.

### Platform-specific gotchas

- **T527 OpenHarmony**: Must run `bash build/prebuilts_download.sh` (≈10 GB) before first `./build.sh`, or it errors immediately. Kernel source modifications must be committed to the local git repo inside the container since the build clones a fresh copy.
- **T113i**: Must run `source build/envsetup.sh` in the container before any build commands. Container uses `ubuntu:18.04`.
- **RK3562**: U-Boot directory is `U-boot` (capital U), not `u-boot`. Defconfig is `rk3562_defconfig`, not `tl3562-evm_defconfig`. `build.sh` may need `sed` fixes for these mismatches. Disable `gcc-wrapper.py` by renaming to `gcc-wrapper.py.bak`.
- **RK3568**: Must fix kconf GLIBC version mismatch by recompiling conf tool: `cd buildroot/support/kconfig && make -f Makefile.br HOSTCC=gcc conf && cp conf ...output/kconf/conf`.
- **All platforms**: T527 Linux and OH5.0 containers need `--privileged` flag. All paths must not contain Chinese characters, spaces, or special chars.

### Build compilation entrypoints (inside respective containers)

| Platform | Build cmd | Pack cmd | Work dir inside container |
|----------|-----------|----------|---------------------------|
| T527 Linux | `./build.sh` | `./build.sh pack` | `/workspace/OKT527-linux-sdk` |
| T527 OH5.0 | `./build.sh --product-name okt527 --ccache` | `cd device/board/forlinx/okt527/kernel/build && ./pack.sh` | `/home/openharmony/forlinx-5.0-release` |
| T113i | `source build/envsetup.sh && ./build.sh` | `./build.sh pack` | `/workspace/tina5.0_v1.0` |
| RK3562 | `./ubuntu/build.sh all` | (included in `all`) | `/workspace` |
| RK3568 | `./build.sh` | (automatic) | `/workspace/OK3568-linux-source` |

### Common fixes (repeat across all platforms)

- **Permission denied**: `sudo chown -R $USER:$USER .` in the SDK root on the host
- **`python: command not found`**: `ln -sf /usr/bin/python3 /usr/bin/python` inside the container
- **Docker pull fails**: Configure registry mirror `https://ccr.ccs.tencentyun.com/` in `/etc/docker/daemon.json`
- **Parallel builds**: Never compile multiple platforms simultaneously — I/O and memory will crash the host

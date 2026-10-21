# Makefile — tcpserver (RK3568 / aarch64 静态编译)
#
# 用法:
#   make                       # 用下方默认 CROSS（相对仓库路径）交叉编译
#   make CROSS=aarch64-none-linux-gnu-   # 工具链已在 PATH 时
#   make CROSS=/workspace/OK3568-linux-source/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-   # 容器内
#   make NATIVE=1              # 本机 x86 调试
#   make clean

TARGET  := tcpserver
SRC     := tcpserver.c
CFLAGS  ?= -O2 -Wall

ifdef NATIVE
CC      := gcc
LDFLAGS :=
STRIP   := strip
else
# 默认指向本仓库自带的 aarch64 工具链（相对本 Makefile 目录）
CROSS   ?= ../../../rk3568_sdk/OK3568-linux-source/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
CC      := $(CROSS)gcc
STRIP   := $(CROSS)strip
LDFLAGS := -static
endif

.PHONY: all clean native

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
	-$(STRIP) $@ 2>/dev/null || true
	@echo "built: $(TARGET)  (CC=$(CC))"

native:
	$(MAKE) NATIVE=1

clean:
	rm -f $(TARGET)

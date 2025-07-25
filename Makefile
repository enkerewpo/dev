# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025 wheatfox
# Author: wheatfox <wheatfox17@icloud.com>

ARCH ?= aarch64
LINUX_ARCH ?= $(ARCH)
LINUX_DEFCONFIG ?= defconfig
LINUX_SRC_DIR ?= ../linux
NUM_JOBS ?= $(shell nproc)

ifeq ($(ARCH),x86_64)
LINUX_ARCH = x86
LINUX_DEFCONFIG = x86_64_defconfig
else ifeq ($(ARCH),aarch64)
LINUX_ARCH = arm64
LINUX_DEFCONFIG = defconfig
else ifeq ($(ARCH),loongarch64)
LINUX_ARCH = loongarch
LINUX_DEFCONFIG = loongson3_defconfig
else
$(error Unsupported architecture: $(ARCH))
endif

export ARCH LINUX_ARCH LINUX_DEFCONFIG

all: kernel-config kernel-build rootfs

.PHONY: kernel-config
# we use clang toolchain to build the kernel and rootfs
kernel-config:
	make -C $(LINUX_SRC_DIR) ARCH=$(LINUX_ARCH) LLVM=1 $(LINUX_DEFCONFIG)

.PHONY: kernel-build
kernel-build:
	time make -C $(LINUX_SRC_DIR) ARCH=$(LINUX_ARCH) LLVM=1 -j$(NUM_JOBS)

.PHONY: kernel-menuconfig
kernel-menuconfig:
	make -C $(LINUX_SRC_DIR) ARCH=$(LINUX_ARCH) LLVM=1 menuconfig

.PHONY: rootfs
rootfs:
	@echo "rootfs"

.PHONY: run
run:
	@echo "run"

.PHONY: clean
clean:
	rm -rf build
	if [ -d $(LINUX_SRC_DIR)/Documentation/Kbuild ]; then rm -rf $(LINUX_SRC_DIR)/Documentation/Kbuild; fi
	make -C $(LINUX_SRC_DIR) ARCH=$(LINUX_ARCH) clean
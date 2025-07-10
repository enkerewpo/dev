# Makefile for eBPF programs
BPF_CC = clang
LLVM_STRIP = llvm-strip
LLVM_OBJDUMP = llvm-objdump
LLVM_READELF = llvm-readelf
LLVM_LLC = llc
CROSS_COMPILE ?= loongarch64-unknown-linux-gnu-
CC = $(CROSS_COMPILE)gcc
BPF_CFLAGS = -g -O2 -target bpf -nostdinc -D__TARGET_ARCH_loongarch
CFLAGS = -g -Wall -Werror -static-libgcc -D__TARGET_ARCH_loongarch
BPFTOOL = bpftool

# Build directory for all artifacts
BUILD_DIR = build

# Kernel headers path - use the Linux source tree
PROJECT_ROOT ?= ../..
HEADERS ?= -I$(PROJECT_ROOT)/build/usr/include
LINUX_SRC ?= $(PROJECT_ROOT)/linux-git
# BPF_HEADERS ?= -I$(LINUX_SRC)/samples/bpf/libbpf/include
# LIBBPF_LIBRARY_DIR ?= -L$(LINUX_SRC)/samples/bpf/libbpf
BPF_HEADERS ?= -I$(LINUX_SRC)/tools/lib/
LOCAL_BUILD_LIB_DIR ?= $(PROJECT_ROOT)/lib/result
LOCAL_BUILD_LIB_INCLUDE ?= -I$(LOCAL_BUILD_LIB_DIR)/include
LOCAL_BUILD_LIB_LIB ?= -L$(LOCAL_BUILD_LIB_DIR)/lib
LIBBPF_LIBRARY_DIR ?= -L$(LINUX_SRC)/tools/lib/bpf
LIBBPF_LIBRARY = -lbpf -lz -lzstd -lelf

TARGET_EBPF_SRCS = $(wildcard *.bpf.c)
TARGET_LOADER_PROGRAM = loader
TARGET_LOADER_SRC = $(TARGET_LOADER_PROGRAM).c

all: $(BUILD_DIR) \
	vmlinux.h \
	$(addprefix $(BUILD_DIR)/,$(TARGET_EBPF_SRCS:.bpf.c=.bpf.o)) \
	$(BUILD_DIR)/$(TARGET_LOADER_PROGRAM)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

vmlinux.h: $(BUILD_DIR)
	$(BPFTOOL) btf dump file $(LINUX_SRC)/../build/vmlinux format c > $@

# Compile eBPF program
$(BUILD_DIR)/%.bpf.o: %.bpf.c vmlinux.h
	$(BPF_CC) $(BPF_CFLAGS) $(HEADERS) $(BPF_HEADERS) -c $< -o $@
	$(BPF_CC) $(BPF_CFLAGS) $(HEADERS) $(BPF_HEADERS) -S -emit-llvm -g -O0 -c $< -o $(@:.bpf.o=.bpf.ll)
	$(LLVM_STRIP) -g $@
	$(LLVM_OBJDUMP) -S $@ > $(@:.bpf.o=.bpf.asm)
	$(LLVM_READELF) -a $@ > $(@:.bpf.o=.bpf.info)

# Compile loader program
$(BUILD_DIR)/$(TARGET_LOADER_PROGRAM): $(TARGET_LOADER_SRC) $(addprefix $(BUILD_DIR)/,$(TARGET_EBPF_SRCS:.bpf.c=.bpf.o)) vmlinux.h
	$(CC) $(CFLAGS) $(HEADERS) $(BPF_HEADERS) $(TARGET_LOADER_SRC) $(LOCAL_BUILD_LIB_INCLUDE) $(LOCAL_BUILD_LIB_LIB) $(LIBBPF_LIBRARY_DIR) $(LIBBPF_LIBRARY) -o $@

clean:
	rm -rf $(BUILD_DIR)
	rm -rf vmlinux.h

.PHONY: all clean 
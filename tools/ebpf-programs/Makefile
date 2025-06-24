# Makefile for eBPF programs
CC = clang
LLVM_STRIP = llvm-strip
BPF_CFLAGS = -g -target bpf -nostdinc

# Kernel headers path - use the Linux source tree
KERNEL_HEADERS ?= -I../../linux-git/include \
	-I../../linux-git/include/uapi \
	-I../../build/include/generated \
	-I../../build/include/generated/uapi \
	-I../../build/include
ARCH_HEADERS ?= -I../../linux-git/arch/loongarch/include \
	-I../../linux-git/arch/loongarch/include/uapi \
	-I../../build/arch/loongarch/include/generated/uapi \
	-I../../build/arch/loongarch/include/generated
LINUX_SRC ?= ../../linux-git

# Default target
all: ebpf1.o

# Compile eBPF program
ebpf1.o: ebpf1.c
	$(CC) $(BPF_CFLAGS) \
		-include ../../linux-git/include/linux/kconfig.h \
		$(KERNEL_HEADERS) \
		$(ARCH_HEADERS) \
		-c $< -o $@
	$(LLVM_STRIP) -g $@

# Clean build artifacts
clean:
	rm -f *.o

.PHONY: all clean 
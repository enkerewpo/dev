# Makefile for eBPF programs
CC = clang
LLVM_STRIP = llvm-strip
BPF_CFLAGS = -g -target bpf -nostdinc

# Kernel headers path - use the Linux source tree
KERNEL_HEADERS ?= ../../linux-git/include
ARCH_HEADERS ?= ../../linux-git/arch/loongarch/include
LINUX_SRC ?= ../../linux-git

# Default target
all: ebpf1.o

# Compile eBPF program
ebpf1.o: ebpf1.c
	$(CC) $(BPF_CFLAGS) \
		-I$(KERNEL_HEADERS) \
		-I$(ARCH_HEADERS) \
		-c $< -o $@
	$(LLVM_STRIP) -g $@

# Clean build artifacts
clean:
	rm -f *.o

.PHONY: all clean 
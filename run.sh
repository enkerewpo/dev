#!/bin/bash

# https://www.qemu.org/docs/master/system/loongarch/virt.html

# Load chosen kernel version
if [[ ! -f .chosen ]]; then
    echo "Error: .chosen file not found"
    exit 1
fi

CHOSEN=$(cat .chosen)
KERNEL_PATH="linux-${CHOSEN}/arch/loongarch/boot/vmlinux.efi"

# Check if kernel exists
if [ ! -f "$KERNEL_PATH" ]; then
    echo "Error: Kernel not found at $KERNEL_PATH"
    exit 1
fi

# Check if rootfs exists and fix permissions
ROOTFS_PATH="nix-rootfs/rootfs.ext4"
if [ ! -f "$ROOTFS_PATH" ]; then
    echo "Error: Rootfs not found at $ROOTFS_PATH"
    exit 1
fi

# Check and fix permissions
if [ ! -w "$ROOTFS_PATH" ]; then
    echo "Fixing permissions for $ROOTFS_PATH"
    sudo chmod 666 "$ROOTFS_PATH"
fi

qemu-system-loongarch64 -m 16G -cpu la464 \
    -machine virt \
    -smp 1 -bios firmware/QEMU_EFI.fd -kernel $KERNEL_PATH \
    -append "earlyprintk=serial console=ttyS0,115200 root=/dev/vda rw" \
    -drive file=$ROOTFS_PATH,format=raw,if=none,id=rootfs \
    -device virtio-blk-pci,drive=rootfs,bus=pcie.0,addr=0x5 \
    -serial mon:stdio \
    -device virtio-net-pci,netdev=net0,bus=pcie.0,addr=0x6 \
    -netdev user,id=net0 \
    --nographic
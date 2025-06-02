#!/bin/bash

# Architecture configuration
ARCH_CONFIGS=(
    "loongarch:loongarch64/boot/vmlinux.efi:la464:QEMU_EFI.fd:uefi"
    "arm64:arm64/boot/Image:max:u-boot-aarch64.bin:uboot"
)

# Default architecture (can be overridden by ARCH environment variable)
DEFAULT_ARCH="arm64"
ARCH=${ARCH:-${DEFAULT_ARCH}}

# Set architecture-specific variables
KERNEL_SUBPATH=""
CPU_TYPE=""
FIRMWARE_FILE=""
BOOT_TYPE=""

for config in "${ARCH_CONFIGS[@]}"; do
    IFS=':' read -r arch_name kernel_path cpu_type firmware_file boot_type <<< "${config}"
    if [[ "${ARCH}" == "${arch_name}" ]]; then
        KERNEL_SUBPATH="${kernel_path}"
        CPU_TYPE="${cpu_type}"
        FIRMWARE_FILE="${firmware_file}"
        BOOT_TYPE="${boot_type}"
        break
    fi
done

if [[ -z "${KERNEL_SUBPATH}" ]]; then
    echo "Error: Unsupported architecture: ${ARCH}. Supported architectures: $(printf '%s ' "${ARCH_CONFIGS[@]}" | cut -d: -f1)"
    exit 1
fi

# Load chosen kernel version
if [[ ! -f .chosen ]]; then
    echo "Error: .chosen file not found"
    exit 1
fi

CHOSEN=$(cat .chosen)
KERNEL_PATH="linux-${CHOSEN}/arch/${KERNEL_SUBPATH}"

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

# Common QEMU parameters
QEMU_OPTS=(
    "-m" "16G"
    "-cpu" "${CPU_TYPE}"
    "-machine" "virt"
    "-smp" "1"
    "-drive" "file=${ROOTFS_PATH},format=raw,if=none,id=rootfs"
    "-device" "virtio-blk-pci,drive=rootfs,bus=pcie.0,addr=0x5"
    "-serial" "mon:stdio"
    "-device" "virtio-net-pci,netdev=net0,bus=pcie.0,addr=0x6"
    "-netdev" "user,id=net0"
    "--nographic"
)

# Add architecture-specific boot parameters
if [[ "${BOOT_TYPE}" == "uefi" ]]; then
    QEMU_OPTS+=(
        "-bios" "firmware/${FIRMWARE_FILE}"
        "-kernel" "${KERNEL_PATH}"
        "-append" "earlyprintk=serial console=ttyS0,115200 root=/dev/vda rw"
    )
elif [[ "${BOOT_TYPE}" == "uboot" ]]; then
    QEMU_OPTS+=(
        "-bios" "firmware/${FIRMWARE_FILE}"
        "-kernel" "${KERNEL_PATH}"
        "-dtb" "linux-${CHOSEN}/arch/arm64/boot/dts/qemu/qemu-arm64.dtb"
    )
fi

QEMU_SUFFIX=""
if [[ "${ARCH}" == "arm64" ]]; then
    QEMU_SUFFIX="aarch64"
elif [[ "${ARCH}" == "loongarch" ]]; then
    QEMU_SUFFIX="loongarch64"
fi

# Run QEMU
echo "Starting QEMU for ${ARCH} architecture using ${BOOT_TYPE} boot..."
qemu-system-${QEMU_SUFFIX} "${QEMU_OPTS[@]}"
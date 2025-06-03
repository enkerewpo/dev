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
CPU_TYPE=""

for config in "${ARCH_CONFIGS[@]}"; do
    IFS=':' read -r arch_name kernel_path cpu_type firmware_file boot_type <<< "${config}"
    if [[ "${ARCH}" == "${arch_name}" ]]; then
        CPU_TYPE="${cpu_type}"
        break
    fi
done

if [[ -z "${CPU_TYPE}" ]]; then
    echo "Error: Unsupported architecture: ${ARCH}. Supported architectures: $(printf '%s ' "${ARCH_CONFIGS[@]}" | cut -d: -f1)"
    exit 1
fi

# Check if NixOS SD image exists
SD_IMAGE_PATH="image/sd-image/nixos-image-sd-card-25.11pre-git-aarch64-linux.img"
if [ ! -f "$SD_IMAGE_PATH" ]; then
    echo "Error: NixOS SD image not found at $SD_IMAGE_PATH"
    exit 1
fi

# Kill any existing QEMU processes
echo "Cleaning up any existing QEMU processes..."
pkill -f "qemu-system-${ARCH}" || true

# Wait a moment for processes to clean up
sleep 1

# Check and fix permissions
echo "Checking and fixing image file permissions..."
sudo chmod 666 "$SD_IMAGE_PATH"

# Common QEMU parameters
QEMU_OPTS=(
    "-m" "4G"
    "-cpu" "${CPU_TYPE}"
    "-smp" "1"
    "-drive" "file=${SD_IMAGE_PATH},format=raw,if=none,id=sd"
    "-device" "virtio-blk-pci,drive=sd,bus=pcie.0,addr=0x5"
    "-serial" "mon:stdio"
    "-device" "virtio-net-pci,netdev=net0,bus=pcie.0,addr=0x6"
    "-netdev" "user,id=net0"
    "-nographic"
    "-append" "console=ttyAMA0 root=/dev/vda2 rw debug"
    "-kernel" "linux-git/arch/arm64/boot/Image"
)

if [[ "${ARCH}" == "arm64" ]]; then
    QEMU_OPTS+=(
        "-machine" "virt,virtualization=on"
    )
elif [[ "${ARCH}" == "loongarch" ]]; then
    QEMU_OPTS+=(
        "-machine" "virt"
    )
fi

QEMU_SUFFIX=""
if [[ "${ARCH}" == "arm64" ]]; then
    QEMU_SUFFIX="aarch64"
elif [[ "${ARCH}" == "loongarch" ]]; then
    QEMU_SUFFIX="loongarch64"
fi

# Run QEMU
echo "Starting QEMU for ${ARCH} architecture..."
qemu-system-${QEMU_SUFFIX} "${QEMU_OPTS[@]}"
#!/bin/bash

# Architecture configuration
ARCH_CONFIGS=(
    "loongarch64:build/arch/loongarch/boot/vmlinux.efi:la464:firmware/QEMU_EFI.fd:uefi"
    "aarch64:build/arch/arm64/boot/Image:max:firmware/u-boot-aarch64.bin:uboot"
)

ARCH=$1
if [ -z "$ARCH" ]; then
    echo "not setting arch, use default loongarch64"
    ARCH="loongarch64"
fi

# Set architecture-specific variables
CPU_TYPE=""
KERNEL_PATH=""
FIRMWARE_FILE=""
BOOT_TYPE=""

for config in "${ARCH_CONFIGS[@]}"; do
    IFS=':' read -r arch_name kernel_path cpu_type firmware_file boot_type <<< "${config}"
    if [[ "${ARCH}" == "${arch_name}" ]]; then
        CPU_TYPE="${cpu_type}"
        KERNEL_PATH="${kernel_path}"
        FIRMWARE_FILE="${firmware_file}"
        BOOT_TYPE="${boot_type}"
        break
    fi
done

if [[ -z "${CPU_TYPE}" ]]; then
    echo "Error: Unsupported architecture: ${ARCH}. Supported architectures: $(printf '%s ' "${ARCH_CONFIGS[@]}" | cut -d: -f1)"
    exit 1
fi

# Check if NixOS SD image exists for the specific architecture
SD_IMAGE_PATH="image/sd-image/nixos-image-sd-card-25.11pre-git-${ARCH}-linux.img"
if [ ! -f "$SD_IMAGE_PATH" ]; then
    echo "Error: NixOS SD image not found at $SD_IMAGE_PATH"
    echo "Available images:"
    ls -la image/sd-image/ 2>/dev/null || echo "No images found in image/sd-image/"
    exit 1
fi

# Check if tools directory exists
if [ ! -d "tools" ]; then
    echo "Warning: tools directory not found, creating empty tools directory..."
    mkdir -p tools
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
    "-drive" "file=fat:rw:tools,format=raw,if=none,id=tools"
    "-device" "virtio-blk-pci,drive=tools,bus=pcie.0,addr=0x7"
    "-serial" "mon:stdio"
    "-device" "virtio-net-pci,netdev=net0,bus=pcie.0,addr=0x6"
    "-netdev" "user,id=net0"
    "-nographic"
)

# UEFI boot configuration
if [[ "${BOOT_TYPE}" == "uefi" ]]; then
    echo "Configuring UEFI boot..."
    # Set console device based on architecture
    if [[ "${ARCH}" == "loongarch64" ]]; then
        CONSOLE_DEVICE="ttyS0"
    else
        CONSOLE_DEVICE="ttyAMA0"
    fi
    
    QEMU_OPTS+=(
        "-bios" "${FIRMWARE_FILE}"
        "-kernel" "${KERNEL_PATH}"
        "-append" "console=${CONSOLE_DEVICE} root=/dev/vda2 rw debug"
    )
else
    echo "Configuring legacy boot..."
    # Set console device based on architecture
    if [[ "${ARCH}" == "loongarch64" ]]; then
        CONSOLE_DEVICE="ttyS0"
    else
        CONSOLE_DEVICE="ttyAMA0"
    fi
    
    QEMU_OPTS+=(
        "-kernel" "${KERNEL_PATH}"
        "-append" "console=${CONSOLE_DEVICE} root=/dev/vda2 rw debug"
    )
fi

# Architecture-specific machine configuration
if [[ "${ARCH}" == "aarch64" ]]; then
    QEMU_OPTS+=(
        "-machine" "virt,virtualization=on"
    )
elif [[ "${ARCH}" == "loongarch64" ]]; then
    QEMU_OPTS+=(
        "-machine" "virt"
    )
fi

# Set QEMU binary suffix
QEMU_SUFFIX=""
if [[ "${ARCH}" == "aarch64" ]]; then
    QEMU_SUFFIX="aarch64"
elif [[ "${ARCH}" == "loongarch64" ]]; then
    QEMU_SUFFIX="loongarch64"
fi

# Run QEMU
echo "Starting QEMU for ${ARCH} architecture with ${BOOT_TYPE} boot..."
echo "Image: ${SD_IMAGE_PATH}"
echo "Kernel: ${KERNEL_PATH}"
echo "Firmware: ${FIRMWARE_FILE}"
echo "Tools directory mounted as second disk (virtio-blk-pci at addr=0x7)"
echo "Command: qemu-system-${QEMU_SUFFIX} ${QEMU_OPTS[*]}"
echo ""

qemu-system-${QEMU_SUFFIX} "${QEMU_OPTS[@]}"
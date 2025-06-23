#!/bin/bash

set -e

export NIXPKGS_ALLOW_BROKEN=1
export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

ARCH=$1
if [ "$ARCH" == "aarch64" ]; then
    nix-build aarch64.nix --show-trace --log-format bar -A image --out-link image
elif [ "$ARCH" == "loongarch64" ]; then
    nix-build loongarch.nix --show-trace --log-format bar -A image --out-link image
else
    echo "Invalid architecture: $ARCH"
    exit 1
fi

NIXOS_VERSION="25.11pre-git"
IMG_PATH="image/sd-image/nixos-image-sd-card-${NIXOS_VERSION}-${ARCH}-linux.img"

if [ ! -f "$IMG_PATH" ]; then
    echo "Error: Image file not found at $IMG_PATH"
    exit 1
fi

MOUNT_DIR="mount"
BOOT_MOUNT="$MOUNT_DIR/boot"
ROOT_MOUNT="$MOUNT_DIR/root"

cleanup() {
    echo "Cleaning up..."
    while mountpoint -q "$ROOT_MOUNT"; do
        sudo umount "$ROOT_MOUNT"
    done
    while mountpoint -q "$BOOT_MOUNT"; do
        sudo umount "$BOOT_MOUNT"
    done
    if [ -e "$LOOP_DEV" ]; then
        sudo losetup -d "$LOOP_DEV"
    fi
    sudo rm -rf "$MOUNT_DIR"
}

trap cleanup EXIT

mount_image() {
    mkdir -p "$BOOT_MOUNT" "$ROOT_MOUNT"

    LOOP_DEV=$(sudo losetup -f --show "$IMG_PATH")
    sudo partprobe "$LOOP_DEV"

    echo "Mounting boot partition..."
    sudo mount "${LOOP_DEV}p1" "$BOOT_MOUNT"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mount boot partition"
        exit 1
    fi

    echo "Mounting root partition..."
    sudo mount "${LOOP_DEV}p2" "$ROOT_MOUNT"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mount root partition"
        exit 1
    fi

    echo "Image mounted successfully!"
    echo "Boot partition mounted at: $BOOT_MOUNT"
    echo "Root partition mounted at: $ROOT_MOUNT"
}

mount_image

MODULE_INSTALL_DIR="build/build/modules-install"

if [ -d "$MODULE_INSTALL_DIR" ]; then
    echo "Module install directory found at: $MODULE_INSTALL_DIR"
    echo "Copying modules to tools directory..."
    sudo cp -r "$MODULE_INSTALL_DIR"/* "$ROOT_MOUNT"
else
    echo "Error: Module install directory not found at: $MODULE_INSTALL_DIR"
    exit 1
fi

echo "unmounting image..."
cleanup

echo "Done"
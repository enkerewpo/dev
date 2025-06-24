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
    echo "error: invalid architecture: $ARCH"
    exit 1
fi

NIXOS_VERSION="25.11pre-git"
IMG_PATH="image/sd-image/nixos-image-sd-card-${NIXOS_VERSION}-${ARCH}-linux.img"

if [ ! -f "$IMG_PATH" ]; then
    echo "error: image file not found at $IMG_PATH"
    exit 1
fi

MOUNT_DIR="mount"
BOOT_MOUNT="$MOUNT_DIR/boot"
ROOT_MOUNT="$MOUNT_DIR/root"

cleanup() {
    echo "cleaning up..."
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
    sudo mkdir -p "$BOOT_MOUNT" "$ROOT_MOUNT"

    LOOP_DEV=$(sudo losetup -f --show "$IMG_PATH")
    sudo partprobe "$LOOP_DEV"

    echo "mounting boot partition..."
    sudo mount "${LOOP_DEV}p1" "$BOOT_MOUNT"
    if [ $? -ne 0 ]; then
        echo "error: failed to mount boot partition"
        exit 1
    fi

    echo "mounting root partition..."
    sudo mount "${LOOP_DEV}p2" "$ROOT_MOUNT"
    if [ $? -ne 0 ]; then
        echo "error: failed to mount root partition"
        exit 1
    fi

    echo "image mounted successfully!"
    echo "boot partition mounted at: $BOOT_MOUNT"
    echo "root partition mounted at: $ROOT_MOUNT"
}

sudo mkdir -p "$ROOT_MOUNT/usr/include"
sudo mkdir -p "$ROOT_MOUNT/lib"

# copy modules to tools directory
copy_modules() {
    MODULE_INSTALL_DIR="build/build/modules-install/lib"
    if [ -d "$MODULE_INSTALL_DIR" ]; then
        echo "module install directory found at: $MODULE_INSTALL_DIR"
        echo "copying modules to tools directory..."
        sudo cp -r "$MODULE_INSTALL_DIR"/* "$ROOT_MOUNT/lib"
    else
        echo "warning: module install directory not found at: $MODULE_INSTALL_DIR, so we will not copy modules to tools directory"
    fi
}

# copy libbpf to tools directory
copy_libbpf() {
    LIBBPF_DIR="linux-git/tools/lib/bpf"
    # just copy the entire bpf folder into root /lib/libbpf
    sudo cp -r "$LIBBPF_DIR" "$ROOT_MOUNT/lib/bpf"
    echo "libbpf copied to root /lib/bpf/"
}

mount_image
copy_modules
copy_libbpf

echo "done"
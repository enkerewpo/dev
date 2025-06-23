#!/bin/bash

IMG_PATH="image/sd-image/nixos-image-sd-card-25.11pre-git-loongarch64-linux.img"

if [ ! -f "$IMG_PATH" ]; then
    echo "Error: Image file not found at $IMG_PATH"
    exit 1
fi

MOUNT_DIR="mount"
BOOT_MOUNT="$MOUNT_DIR/boot"
ROOT_MOUNT="$MOUNT_DIR/root"

cleanup() {
    echo "Cleaning up..."
    if mountpoint -q "$ROOT_MOUNT"; then
        sudo umount "$ROOT_MOUNT"
    fi
    if mountpoint -q "$BOOT_MOUNT"; then
        sudo umount "$BOOT_MOUNT"
    fi
    if [ -e "$LOOP_DEV" ]; then
        sudo losetup -d "$LOOP_DEV"
    fi
    sudo rm -rf "$MOUNT_DIR"
}

trap cleanup EXIT

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
echo "Press Enter to unmount and exit..."
read 
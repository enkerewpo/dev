#!/bin/bash

IMG_PATH="image/sd-image/nixos-image-sd-card-25.11pre-git-loongarch64-linux.img"

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

mkdir -p "$BOOT_MOUNT" "$ROOT_MOUNT"

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
echo "press enter to unmount and exit..."
read
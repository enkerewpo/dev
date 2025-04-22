# Nix-LoongArch

A Nix-based Linux distribution development environment for LoongArch architecture.

## Overview

This project provides a complete development environment for building and testing Linux on LoongArch architecture using Nix package manager. It includes:

- Custom Linux kernel configuration
- Root filesystem generation
- EFI boot support
- Development tools and dependencies

## Quick Start

1. Build the default configuration:
   ```bash
   ./build.sh def
   ```

2. Build the Linux kernel:
   ```bash
   ./build.sh kernel
   ```

3. Build the root filesystem:
   ```bash
   ./build.sh rootfs
   ```

4. Run the system with EFI boot:
   ```bash
   ./run_efi.sh
   ```
## Some Notes

1. export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 (libseccomp)
2. for not supported packages in nixpkgs (like systemd, qemu, rt-tests, etc.), we use the CLFS toolchain preinstalled on the host machine.
3. download the CLFS toolchain from https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-8.0-cross-tools-gcc-full.tar.xz and extract it, add `loongarch64-unknown-linux-gnu-*` to the `PATH` environment variable.
4. echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf
5. sudo systemctl restart nix-daemon

## License

Copyright (c) 2025 wheatfox
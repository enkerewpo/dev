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

## License

Copyright (c) 2025 wheatfox
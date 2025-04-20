#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2024-2025 wheatfox <wheatfox17@icloud.com>
#
# Linux Kernel Development Build Script
# This script manages the build process for Linux kernel with Rust support,
# specifically targeting the Loongarch64 architecture.

set -euo pipefail

###################
# Configuration
###################

# Build configuration (these can be readonly)
readonly ARCH="loongarch"
readonly CROSS_COMPILE="loongarch64-unknown-linux-gnu-"
readonly TARGET_DEFCONFIG="loongson3_wheatfox_defconfig"
readonly LOG_DIR="build_logs"

# Dynamic configuration (these should not be readonly)
USE_LLVM=${USE_LLVM:-1} # Can be overridden by environment variable
LLVM_HOME=${LLVM_HOME:-"/home/wheatfox/tryredox/clang+llvm-18.1.8-x86_64-linux-gnu-ubuntu-18.04/bin"}
NUM_JOBS=$(nproc)

# Variables for workspace paths (will be set in setup_workspace)
CHOSEN=""
LINUX_SRC_DIR=""
WORKDIR=""
FLAG=""

# Variables for tools (will be set in setup_toolchain)
CLANG=""
LLD=""
LLVM_OBJCOPY=""
LLVM_READELF=""
LLVM_OBJDUMP=""
GNU_PREFIX="loongarch64-unknown-linux-gnu-"
GNU_GCC=""
GNU_OBJCOPY=""
GNU_READELF=""
GNU_OBJDUMP=""

# Rust configuration
RUST_VERSION="1.75.0"
RUST_FLAGS="-Copt-level=2"

# Nix configuration
NIX_ROOTFS_DIR="nix-rootfs"
NIX_CONFIG_DIR="nix-config"
NIX_SYSTEM="loongarch64-linux"
NIX_PKGS="nixpkgs#pkgsCross.loongarch64-linux"

###################
# Logging Functions
###################

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $1" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

die() {
    log_error "$1"
    exit 1
}

###################
# Utility Functions
###################

setup_workspace() {
    mkdir -p "${LOG_DIR}"

    # Load chosen kernel version
    if [[ ! -f .chosen ]]; then
        print_available_versions
        die ".chosen file not found. Please set the kernel version suffix in the .chosen file."
    fi

    CHOSEN=$(cat .chosen)
    LINUX_SRC_DIR=$(realpath "linux-${CHOSEN}")
    WORKDIR=$(dirname "${LINUX_SRC_DIR}")
    FLAG="${WORKDIR}/.flag"

    if [[ ! -d "linux-${CHOSEN}" ]]; then
        print_available_versions
        die "linux-${CHOSEN} directory not found"
    fi

    log_info "Using Linux source: linux-${CHOSEN}"
}

print_available_versions() {
    log_info "Available versions to set in the .chosen file:"
    local found=0
    for dir in linux-*; do
        if [[ -d "${dir}" ]]; then
            log_info "${dir#linux-}"
            found=1
        fi
    done
    if [[ $found -eq 0 ]]; then
        log_error "No Linux kernel directories found. Please clone a Linux kernel repository first."
    fi
}

check_dependencies() {
    local missing_deps=()

    # Check LLVM tools
    [[ ! -x "${CLANG}" ]] && missing_deps+=("clang")
    [[ ! -x "${LLD}" ]] && missing_deps+=("lld")
    [[ ! -x "${LLVM_OBJCOPY}" ]] && missing_deps+=("llvm-objcopy")
    [[ ! -x "${LLVM_READELF}" ]] && missing_deps+=("llvm-readelf")

    # Check GNU tools
    command -v "${GNU_GCC}" >/dev/null 2>&1 || missing_deps+=("${GNU_GCC}")
    command -v "${GNU_OBJCOPY}" >/dev/null 2>&1 || missing_deps+=("${GNU_OBJCOPY}")
    command -v "${GNU_READELF}" >/dev/null 2>&1 || missing_deps+=("${GNU_READELF}")
    command -v "${GNU_OBJDUMP}" >/dev/null 2>&1 || missing_deps+=("${GNU_OBJDUMP}")

    if ((${#missing_deps[@]} > 0)); then
        log_error "Missing required dependencies:"
        printf '%s\n' "${missing_deps[@]}" >&2
        exit 1
    fi
}

check_rust() {
    if ! command -v rustc >/dev/null 2>&1; then
        die "Rust is not installed. Please install Rust using rustup."
    fi

    if ! command -v cargo >/dev/null 2>&1; then
        die "Cargo is not installed. Please install Rust using rustup."
    fi

    local installed_version
    installed_version=$(rustc --version | cut -d ' ' -f 2)
    if [[ "$(printf '%s\n' "${RUST_VERSION}" "${installed_version}" | sort -V | head -n1)" != "${RUST_VERSION}" ]]; then
        die "Rust version ${RUST_VERSION} or higher is required (found ${installed_version})"
    fi
}

init_submodules() {
    log_info "Initializing submodules"
    git submodule update --init --recursive

    log_info "Submodules:"
    git submodule status
}

check_nix() {
    if ! command -v nix >/dev/null 2>&1; then
        die "Nix is not installed. Please install Nix package manager first."
    fi

    if ! nix --version >/dev/null 2>&1; then
        die "Nix is not properly installed or configured."
    fi
}

setup_nix_rootfs() {
    log_info "Setting up Nix rootfs configuration"

    # Check if Nix configuration files exist
    if [[ ! -f "${NIX_CONFIG_DIR}/default.nix" ]]; then
        die "Nix configuration file ${NIX_CONFIG_DIR}/default.nix not found"
    fi

    if [[ ! -f "${NIX_CONFIG_DIR}/shell.nix" ]]; then
        die "Nix configuration file ${NIX_CONFIG_DIR}/shell.nix not found"
    fi

    log_info "Using Nix configuration from ${NIX_CONFIG_DIR}"
}

build_nix_rootfs() {
    check_nix
    setup_nix_rootfs

    log_info "Building Nix rootfs for ${NIX_SYSTEM}"

    # Create output directory
    mkdir -p "${NIX_ROOTFS_DIR}"

    # Build the rootfs using Nix with experimental features enabled
    if ! nix build --impure ".#" --out-link "${NIX_ROOTFS_DIR}/rootfs.ext4"; then
        die "Failed to build Nix rootfs"
    fi

    if ! nix build --impure ".#rootfs" --out-link "${NIX_ROOTFS_DIR}/rootfs.ext4.link"; then
        die "Failed to build Nix rootfs"
    fi

    if [[ ! -d "${NIX_ROOTFS_DIR}/mount" ]]; then
        mkdir -p "${NIX_ROOTFS_DIR}/mount"
    fi

    # if already mounted, unmount it
    if mount | grep -q "${NIX_ROOTFS_DIR}/mount"; then
        sudo umount "${NIX_ROOTFS_DIR}/mount"
    fi

    # resize the rootfs.ext4 to 1G using sudo resize2fs
    # sudo e2fsck -f "${NIX_ROOTFS_DIR}/rootfs.ext4"
    sudo resize2fs "${NIX_ROOTFS_DIR}/rootfs.ext4" 1G

    # mount the rootfs.ext4 to the mount directory
    sudo mount "${NIX_ROOTFS_DIR}/rootfs.ext4" "${NIX_ROOTFS_DIR}/mount"


    # copy the contents of the rootfs.ext4.link to the mount directory
    sudo cp -r "${NIX_ROOTFS_DIR}/rootfs.ext4.link"/* "${NIX_ROOTFS_DIR}/mount"
    
    ls -la "${NIX_ROOTFS_DIR}/mount"

    sudo umount "${NIX_ROOTFS_DIR}/mount"

    log_info "Nix rootfs built successfully in ${NIX_ROOTFS_DIR}/mount"
}

###################
# Build Functions
###################

# Function to find tool in LLVM_HOME or PATH
find_tool() {
    local tool=$1
    local llvm_path="${LLVM_HOME}/${tool}"

    if [[ ${USE_LLVM} -eq 1 ]]; then
        if [[ -x "${llvm_path}" ]]; then
            echo "${llvm_path}"
        else
            # Try to find in PATH with llvm- or clang- prefix
            local path_tool
            for prefix in "" "llvm-" "clang-"; do
                path_tool=$(command -v "${prefix}${tool}")
                if [[ -n "${path_tool}" ]]; then
                    echo "${path_tool}"
                    return 0
                fi
            done
            die "Cannot find ${tool} in ${LLVM_HOME} or PATH"
        fi
    else
        echo ""
    fi
}

# Function to get GNU tool path
get_gnu_tool() {
    local tool=$1
    local gnu_tool="${CROSS_COMPILE}${tool}"
    command -v "${gnu_tool}" || die "Cannot find ${gnu_tool} in PATH"
}

# Set up toolchain
setup_toolchain() {
    if [[ ${USE_LLVM} -eq 1 ]]; then
        log_info "Using LLVM toolchain"
        CLANG=$(find_tool "clang")
        LLD=$(find_tool "ld.lld")
        LLVM_OBJCOPY=$(find_tool "llvm-objcopy")
        LLVM_READELF=$(find_tool "llvm-readelf")
        LLVM_OBJDUMP=$(find_tool "llvm-objdump")

        # Verify all LLVM tools are found
        [[ -n "${CLANG}" ]] || die "clang not found"
        [[ -n "${LLD}" ]] || die "ld.lld not found"
        [[ -n "${LLVM_OBJCOPY}" ]] || die "llvm-objcopy not found"
        [[ -n "${LLVM_READELF}" ]] || die "llvm-readelf not found"
        [[ -n "${LLVM_OBJDUMP}" ]] || die "llvm-objdump not found"

        log_info "LLVM toolchain configuration:"
        log_info "  CLANG: ${CLANG}"
        log_info "  LLD: ${LLD}"
        log_info "  OBJCOPY: ${LLVM_OBJCOPY}"
        log_info "  READELF: ${LLVM_READELF}"
        log_info "  OBJDUMP: ${LLVM_OBJDUMP}"
    else
        log_info "Using GNU toolchain"
        # Set up GNU tools for non-LLVM builds
        GNU_GCC=$(get_gnu_tool "gcc")
        GNU_OBJCOPY=$(get_gnu_tool "objcopy")
        GNU_READELF=$(get_gnu_tool "readelf")
        GNU_OBJDUMP=$(get_gnu_tool "objdump")

        log_info "GNU toolchain configuration:"
        log_info "  GCC: ${GNU_GCC}"
        log_info "  OBJCOPY: ${GNU_OBJCOPY}"
        log_info "  READELF: ${GNU_READELF}"
        log_info "  OBJDUMP: ${GNU_OBJDUMP}"
    fi
}

# Get make arguments based on toolchain
get_make_args() {
    local args="-C ${LINUX_SRC_DIR} ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}"

    if [[ ${USE_LLVM} -eq 1 ]]; then
        args+=" LLVM=1"
        args+=" CC=${CLANG}"
        args+=" LD=${LLD}"
        args+=" OBJCOPY=${LLVM_OBJCOPY}"
        args+=" READELF=${LLVM_READELF}"
    fi

    echo "${args}"
}

run_defconfig() {
    log_info "Running defconfig"
    # shellcheck disable=SC2046
    make $(get_make_args) "${TARGET_DEFCONFIG}"
    echo "ROOT" >"${FLAG}"
}

clean_build() {
    log_info "Cleaning the build"
    # shellcheck disable=SC2046
    make $(get_make_args) clean
    rm -f "${FLAG}"
}

run_menuconfig() {
    log_info "Running menuconfig"
    # shellcheck disable=SC2046
    make $(get_make_args) menuconfig
}

save_defconfig() {
    log_info "Saving defconfig"
    cp "${LINUX_SRC_DIR}/.config" "${LINUX_SRC_DIR}/arch/${ARCH}/configs/${TARGET_DEFCONFIG}"
}

build_kernel() {
    [[ ! -f "${FLAG}" ]] && die "Please run 'build def' first"

    check_rust

    log_info "Building kernel with:"
    log_info "  USE_LLVM=${USE_LLVM}"
    log_info "  Jobs=${NUM_JOBS}"
    log_info "  Rust support enabled"

    # Enable Rust support in kernel config
    if ! grep -q "CONFIG_RUST=y" "${LINUX_SRC_DIR}/.config" 2>/dev/null; then
        log_info "Enabling Rust support in kernel config"
        echo "CONFIG_RUST=y" >>"${LINUX_SRC_DIR}/.config"
    fi

    local build_log="${LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"

    # shellcheck disable=SC2046
    if ! make $(get_make_args) -j"${NUM_JOBS}" 2>&1 | tee "${build_log}"; then
        log_error "Build failed. See ${build_log} for details"
        exit 1
    fi

    log_info "Generating debug information"
    if [[ ${USE_LLVM} -eq 1 ]]; then
        "${LLVM_READELF}" -a "${LINUX_SRC_DIR}/vmlinux" >"${LINUX_SRC_DIR}/vmlinux.readelf.txt"
        "${LLVM_OBJDUMP}" -d "${LINUX_SRC_DIR}/vmlinux" >"${LINUX_SRC_DIR}/vmlinux.asm"
    else
        "${GNU_READELF}" -a "${LINUX_SRC_DIR}/vmlinux" >"${LINUX_SRC_DIR}/vmlinux.readelf.txt"
        "${GNU_OBJDUMP}" -d "${LINUX_SRC_DIR}/vmlinux" >"${LINUX_SRC_DIR}/vmlinux.asm"
    fi

    log_info "Generating compile_commands.json"
    (cd "${LINUX_SRC_DIR}" && python3 scripts/clang-tools/gen_compile_commands.py)

    log_info "Build completed successfully"
}

build_rootfs() {
    log_info "Building rootfs"
    build_nix_rootfs
}

show_help() {
    # Color codes
    local RESET="\033[0m"
    local BOLD="\033[1m"
    local WHITE="\033[37m"
    local YELLOW="\033[33m"
    local GREEN="\033[32m"
    local CYAN="\033[36m"

    {
        echo -e "${BOLD}${WHITE}Linux Kernel Build Script${RESET}"
        echo -e "${BOLD}wheatfox (wheatfox17@.icloud.com) ${RESET}\n"

        echo -e "${BOLD}${YELLOW}Usage:${RESET}"
        echo "    ./build [command]"
        echo

        echo -e "${BOLD}${YELLOW}Commands:${RESET}"
        echo -e "    ${BOLD}${GREEN}help${RESET}        Show this help message"
        echo -e "    ${BOLD}${GREEN}def${RESET}         Run defconfig and initialize build"
        echo -e "    ${BOLD}${GREEN}clean${RESET}       Clean the build artifacts"
        echo -e "    ${BOLD}${GREEN}menuconfig${RESET}  Run kernel menuconfig"
        echo -e "    ${BOLD}${GREEN}save${RESET}        Save current config as defconfig"
        echo -e "    ${BOLD}${GREEN}kernel${RESET}      Build the kernel (requires def first)"
        echo -e "    ${BOLD}${GREEN}rootfs${RESET}      Build the root filesystem using Nix"
        echo -e "    ${BOLD}${GREEN}status${RESET}      Show build status and configuration"
        echo -e "    ${BOLD}${GREEN}check${RESET}       Check build dependencies"
        echo

        echo -e "${BOLD}${YELLOW}Build Options:${RESET}"
        echo -e "    ${BOLD}${CYAN}USE_LLVM=${RESET}0|1     Enable/disable LLVM toolchain (default: 1)"
        echo -e "    ${BOLD}${CYAN}LLVM_HOME=${RESET}<path>  Set custom LLVM tools path"
        echo

        echo -e "${BOLD}${YELLOW}Examples:${RESET}"
        echo "    ./build def                    # Configure kernel"
        echo "    ./build kernel                 # Build kernel with LLVM"
        echo "    USE_LLVM=0 ./build kernel     # Build kernel with GNU toolchain"
        echo "    LLVM_HOME=/opt/llvm ./build   # Use custom LLVM path"
        echo

        echo -e "${BOLD}${YELLOW}Toolchain:${RESET}"
        echo "    LLVM: Uses clang ${LLVM_VERSION:-18+} for kernel compilation"
        echo "    GNU:  Uses ${GNU_PREFIX} toolchain"
        echo

        echo -e "${BOLD}${YELLOW}Configuration:${RESET}"
        echo "    Architecture:  ${ARCH}"
        echo "    Target:        ${TARGET_DEFCONFIG}"
        echo "    Jobs:          ${NUM_JOBS}"
        echo

        echo -e "${BOLD}${YELLOW}More Information:${RESET}"
        echo "    Repository:  https://github.com/enkerewpo/nix-loongarch64"
        echo "    License:     GPL-2.0-or-later"
    } | less -R
}

show_status() {
    log_info "Build Status:"
    echo "  Kernel Version: linux-${CHOSEN}"
    echo "  Architecture: ${ARCH}"
    echo "  Compiler: ${LLVM:+LLVM }Clang"
    echo "  Rust Support: Enabled (${RUST_VERSION}+)"
    echo "  Build Config: ${TARGET_DEFCONFIG}"
    echo "  Build Ready: $([[ -f "${FLAG}" ]] && echo "Yes" || echo "No (run 'build def' first)")"
}

check_build_env() {
    log_info "Checking build environment"
    check_dependencies
    check_rust
    log_info "All dependencies satisfied"
}

###################
# Main
###################

main() {
    setup_workspace

    # Call setup_toolchain early in the script
    setup_toolchain

    case "${1:-help}" in
    help | -h | --help) show_help ;;
    def) run_defconfig ;;
    clean) clean_build ;;
    menuconfig) run_menuconfig ;;
    save) save_defconfig ;;
    kernel) build_kernel ;;
    rootfs) build_rootfs ;;
    status) show_status ;;
    check) check_build_env ;;
    *)
        log_error "Unknown command: ${1}"
        show_help
        ;;
    esac
}

main "$@"

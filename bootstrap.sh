#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2025 wheatfox <wheatfox17@icloud.com>
#
# Linux Kernel Development Build Script
# This script manages the build process for Linux kernel with Rust support,
# supporting both Loongarch64 and AArch64 architectures.

set -euo pipefail

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

export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

###################
# Configuration
###################

# Architecture configuration
ARCH_CONFIGS=(
    "loongarch64:loongarch64-unknown-linux-gnu-:wheatfox_defconfig:loongarch64-linux:loongarch.nix"
    "aarch64:aarch64-unknown-linux-gnu-:defconfig:aarch64-linux:aarch64.nix"
)

# Default architecture (can be overridden by ARCH environment variable)
DEFAULT_ARCH="loongarch64"

# Build configuration (these can be readonly)
ARCH=${ARCH:-${DEFAULT_ARCH}}
CROSS_COMPILE=""
TARGET_DEFCONFIG=""
NIX_SYSTEM=""
NIX_FILE=""

# Set architecture-specific variables
for config in "${ARCH_CONFIGS[@]}"; do
    IFS=':' read -r arch_name cross_compile defconfig nix_system nix_file <<< "${config}"
    if [[ "${ARCH}" == "${arch_name}" ]]; then
        CROSS_COMPILE="${cross_compile}"
        TARGET_DEFCONFIG="${defconfig}"
        NIX_SYSTEM="${nix_system}"
        NIX_FILE="${nix_file}"
        log_info "Using architecture: ${arch_name}, cross_compile: ${cross_compile}, defconfig: ${defconfig}, nix_system: ${nix_system}, nix_file: ${nix_file}"
        break
    fi
done

readonly ARCH
readonly CROSS_COMPILE
readonly TARGET_DEFCONFIG
readonly NIX_SYSTEM
readonly NIX_FILE
readonly LOG_DIR="build_logs"
readonly BUILD_DIR=$(realpath "build")  # New build directory for output, we use realpath to make it absolute

# Dynamic configuration (these should not be readonly)
USE_LLVM=${USE_LLVM:-0} # Can be overridden by environment variable, default is 0 because atomics intrinsics for loongarch "+BZ" is only supported in GCC now
LLVM_HOME=${LLVM_HOME:-"/usr/lib/llvm-19/bin"}
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
GNU_PREFIX="${CROSS_COMPILE}"
GNU_GCC=""
GNU_OBJCOPY=""
GNU_READELF=""
GNU_OBJDUMP=""
GNU_LD=""
GNU_AR=""
GNU_NM=""
GNU_STRIP=""

# LLVM library paths
LLVM_LIB_PATH="${LLVM_HOME}/../lib"
export LD_LIBRARY_PATH="${LLVM_LIB_PATH}:${LD_LIBRARY_PATH:-}"

# Rust configuration
RUST_VERSION="1.75.0"
RUST_FLAGS="-Copt-level=2"
RUSTC=$(command -v rustc)
RUST_LIB_SRC="$(${RUSTC} --print sysroot)/lib/rustlib/src/rust/library"

# Nix configuration
NIX_ROOTFS_DIR="nix-rootfs"
NIX_CONFIG_DIR="nix-config"

###################
# Utility Functions
###################

setup_workspace() {
    mkdir -p "${LOG_DIR}"
    mkdir -p "${BUILD_DIR}"

    # Load chosen kernel version
    if [[ ! -f .chosen ]]; then
        print_available_versions
        die ".chosen file not found. Please set the kernel version suffix in the .chosen file."
    fi

    CHOSEN=$(cat .chosen)
    LINUX_SRC_DIR=$(realpath "linux-${CHOSEN}")
    WORKDIR=$(dirname "${LINUX_SRC_DIR}")
    FLAG="${BUILD_DIR}/.flag"

    if [[ ! -d "linux-${CHOSEN}" ]]; then
        print_available_versions
        die "linux-${CHOSEN} directory not found"
    fi

    log_info "Using Linux source: linux-${CHOSEN}"
    log_info "Build output directory: ${BUILD_DIR}"
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
    [[ ! -x "${LLVM_AR}" ]] && missing_deps+=("llvm-ar")
    [[ ! -x "${LLVM_NM}" ]] && missing_deps+=("llvm-nm")
    [[ ! -x "${LLVM_STRIP}" ]] && missing_deps+=("llvm-strip")
    [[ ! -x "${LLVM_OBJCOPY}" ]] && missing_deps+=("llvm-objcopy")
    [[ ! -x "${LLVM_READELF}" ]] && missing_deps+=("llvm-readelf")
    [[ ! -x "${LLVM_OBJDUMP}" ]] && missing_deps+=("llvm-objdump")

    # Check GNU tools
    command -v "${GNU_GCC}" >/dev/null 2>&1 || missing_deps+=("${GNU_GCC}")
    command -v "${GNU_OBJCOPY}" >/dev/null 2>&1 || missing_deps+=("${GNU_OBJCOPY}")
    command -v "${GNU_READELF}" >/dev/null 2>&1 || missing_deps+=("${GNU_READELF}")
    command -v "${GNU_OBJDUMP}" >/dev/null 2>&1 || missing_deps+=("${GNU_OBJDUMP}")
    command -v "${GNU_LD}" >/dev/null 2>&1 || missing_deps+=("${GNU_LD}")
    command -v "${GNU_AR}" >/dev/null 2>&1 || missing_deps+=("${GNU_AR}")
    command -v "${GNU_NM}" >/dev/null 2>&1 || missing_deps+=("${GNU_NM}")
    command -v "${GNU_STRIP}" >/dev/null 2>&1 || missing_deps+=("${GNU_STRIP}")

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
    # print RUST_LIB_SRC and export it
    log_info "RUST_LIB_SRC=${RUST_LIB_SRC}"
    export RUST_LIB_SRC
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

    # do nothing now

    log_info "Using Nix configuration from ${NIX_CONFIG_DIR}"
}

build_nix_rootfs() {
    check_nix
    # setup_nix_rootfs

    # log_info "Building Nix rootfs for ${NIX_SYSTEM} using ${NIX_FILE}"

    # # Create output directory
    # mkdir -p "${NIX_ROOTFS_DIR}"

    # export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

    # NIX_BUILD_CMD1="nix-build --impure --show-trace --no-sandbox --log-format bar -A image --out-link ${NIX_ROOTFS_DIR}/rootfs.ext4 ${NIX_FILE}"
    # NIX_BUILD_CMD2="nix-build --impure --show-trace --no-sandbox --log-format bar -A rootfs --out-link ${NIX_ROOTFS_DIR}/rootfs.ext4.link ${NIX_FILE}"

    # # create a list of commands to run
    # NIX_BUILD_CMDS=("${NIX_BUILD_CMD1}" "${NIX_BUILD_CMD2}")

    # for cmd in "${NIX_BUILD_CMDS[@]}"; do
    #     if ! eval "${cmd}"; then
    #         die "Failed to build Nix rootfs, failed command: ${cmd}"
    #     fi
    # done
    # if [[ ! -d "${NIX_ROOTFS_DIR}/mount" ]]; then
    #     mkdir -p "${NIX_ROOTFS_DIR}/mount"
    # fi

    # # if already mounted, unmount it
    # if mount | grep -q "${NIX_ROOTFS_DIR}/mount"; then
    #     sudo umount "${NIX_ROOTFS_DIR}/mount"
    # fi

    # # run e2fsck in auto fix mode and ignore the return value
    # sudo e2fsck -p -f "${NIX_ROOTFS_DIR}/rootfs.ext4" || true
    # sudo resize2fs "${NIX_ROOTFS_DIR}/rootfs.ext4" 8G || true

    # # mount the rootfs.ext4 to the mount directory
    # sudo mount "${NIX_ROOTFS_DIR}/rootfs.ext4" "${NIX_ROOTFS_DIR}/mount"

    # # copy the contents of the rootfs.ext4.link to the mount directory
    # sudo cp -r "${NIX_ROOTFS_DIR}/rootfs.ext4.link"/* "${NIX_ROOTFS_DIR}/mount"
    
    # sudo cp -r overlay/* "${NIX_ROOTFS_DIR}/mount"

    # # copy modules
    # sudo mkdir -p "${NIX_ROOTFS_DIR}/mount/lib/modules"
    # sudo cp -r "${LINUX_SRC_DIR}/../modules-install"/lib/modules/* "${NIX_ROOTFS_DIR}/mount/lib/modules"

    # ls -la "${NIX_ROOTFS_DIR}/mount"

    # # copy ../qemu/** into ${NIX_ROOTFS_DIR}/mount/opt/qemu-src
    # # create the directory if it doesn't exist
    # # sudo mkdir -p "${NIX_ROOTFS_DIR}/mount/opt/qemu-src"
    # # sudo cp -r ../qemu "${NIX_ROOTFS_DIR}/mount/opt/qemu-src"

    # sudo umount "${NIX_ROOTFS_DIR}/mount"

    # log_info "Nix rootfs built successfully in ${NIX_ROOTFS_DIR}/mount"

    ./nix_build.sh
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
        LLVM_AR=$(find_tool "llvm-ar")
        LLVM_NM=$(find_tool "llvm-nm")
        LLVM_STRIP=$(find_tool "llvm-strip")
        LLVM_LLC=$(find_tool "llc")

        # Verify all LLVM tools are found
        [[ -n "${CLANG}" ]] || die "clang not found"
        [[ -n "${LLD}" ]] || die "ld.lld not found"
        [[ -n "${LLVM_OBJCOPY}" ]] || die "llvm-objcopy not found"
        [[ -n "${LLVM_READELF}" ]] || die "llvm-readelf not found"
        [[ -n "${LLVM_OBJDUMP}" ]] || die "llvm-objdump not found"
        [[ -n "${LLVM_AR}" ]] || die "llvm-ar not found"
        [[ -n "${LLVM_NM}" ]] || die "llvm-nm not found"
        [[ -n "${LLVM_STRIP}" ]] || die "llvm-strip not found"
        [[ -n "${LLVM_LLC}" ]] || die "llc not found"
        # Set LLVM library path
        LLVM_LIB_PATH="${LLVM_HOME}/../lib"
        export LD_LIBRARY_PATH="${LLVM_LIB_PATH}:${LD_LIBRARY_PATH:-}"
        log_info "LLVM library path: ${LLVM_LIB_PATH}"

        log_info "LLVM toolchain configuration:"
        log_info "  CLANG: ${CLANG}"
        log_info "  LLD: ${LLD}"
        log_info "  AR: ${LLVM_AR}"
        log_info "  NM: ${LLVM_NM}"
        log_info "  STRIP: ${LLVM_STRIP}"
        log_info "  OBJCOPY: ${LLVM_OBJCOPY}"
        log_info "  READELF: ${LLVM_READELF}"
        log_info "  OBJDUMP: ${LLVM_OBJDUMP}"
        log_info "  LLC: ${LLVM_LLC}"
    else
        log_info "Using GNU toolchain"
        # Set up GNU tools for non-LLVM builds
        GNU_GCC=$(get_gnu_tool "gcc")
        GNU_OBJCOPY=$(get_gnu_tool "objcopy")
        GNU_READELF=$(get_gnu_tool "readelf")
        GNU_OBJDUMP=$(get_gnu_tool "objdump")
        GNU_LD=$(get_gnu_tool "ld")
        GNU_AR=$(get_gnu_tool "ar")
        GNU_NM=$(get_gnu_tool "nm")
        GNU_STRIP=$(get_gnu_tool "strip")

        log_info "GNU toolchain configuration:"
        log_info "  GCC: ${GNU_GCC}"
        log_info "  OBJCOPY: ${GNU_OBJCOPY}"
        log_info "  READELF: ${GNU_READELF}"
        log_info "  OBJDUMP: ${GNU_OBJDUMP}"
        log_info "  LD: ${GNU_LD}"
        log_info "  AR: ${GNU_AR}"
        log_info "  NM: ${GNU_NM}"
        log_info "  STRIP: ${GNU_STRIP}"
    fi
}

# Get make arguments based on toolchain
get_make_args() {
    local args="O=${BUILD_DIR} ARCH=$(to_linux_arch "${ARCH}") CROSS_COMPILE=${CROSS_COMPILE}"

    if [[ ${USE_LLVM} -eq 1 ]]; then
        args+=" LLVM=1"
        args+=" CC=${CLANG}"
        args+=" LD=${LLD}"
        args+=" AR=${LLVM_AR}"
        args+=" NM=${LLVM_NM}"
        args+=" STRIP=${LLVM_STRIP}"
        args+=" OBJDUMP=${LLVM_OBJDUMP}"
        args+=" READELF=${LLVM_READELF}"
        args+=" LLVM_LINKER=${LLD}"
        args+=" LLC=${LLVM_LLC}"
    fi

    echo "${args}"
}

# Convert architecture to Linux kernel architecture convention
to_linux_arch() {
    local arch=$1
    if [[ "${arch}" == "loongarch64" ]]; then
        echo "loongarch"
    elif [[ "${arch}" == "aarch64" ]]; then
        echo "arm64"
    else
        die "Unsupported architecture: ${arch}"
    fi
}

run_defconfig() {
    log_info "Running defconfig, using ${TARGET_DEFCONFIG}"
    
    # First clean the source tree
    log_info "Cleaning source tree"
    make -C "${LINUX_SRC_DIR}" ARCH="$(to_linux_arch "${ARCH}")" mrproper
    
    # Then run defconfig
    make -C "${LINUX_SRC_DIR}" $(get_make_args) "${TARGET_DEFCONFIG}"
}

clean_build() {
    log_info "Cleaning the build"
    # Clean both the build directory and source tree
    make -C "${LINUX_SRC_DIR}" ARCH="$(to_linux_arch "${ARCH}")" mrproper
    rm -rf "${BUILD_DIR}"
    rm -f "${FLAG}"
}

run_menuconfig() {
    log_info "Running menuconfig"
    make -C "${LINUX_SRC_DIR}" ARCH="$(to_linux_arch "${ARCH}")" mrproper
    make -C "${LINUX_SRC_DIR}" $(get_make_args) menuconfig
}

save_defconfig() {
    log_info "Saving defconfig"
    if [[ ! -f "${BUILD_DIR}/.config" ]]; then
        die "No .config file found in ${BUILD_DIR}"
    fi
    cp -v "${BUILD_DIR}/.config" "${LINUX_SRC_DIR}/arch/${ARCH}/configs/${TARGET_DEFCONFIG}"
    cp -v "${BUILD_DIR}/.config" "configs/${TARGET_DEFCONFIG}"
}

build_kernel() {
    log_info "Building kernel with:"
    log_info "  USE_LLVM=${USE_LLVM}"
    log_info "  Jobs=${NUM_JOBS}"
    log_info "  Rust support enabled"
    log_info "  Build directory: ${BUILD_DIR}"

    rm -rf "${BUILD_DIR}/modules-install"

    # mrproper the source
    make -C "${LINUX_SRC_DIR}" ARCH="$(to_linux_arch "${ARCH}")" mrproper

    # Check Rust availability
    log_info "Checking Rust availability for kernel build"

    cmd="make -C ${LINUX_SRC_DIR} $(get_make_args) rustavailable"
    eval "${cmd}"

    local build_log="${LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"
    # then let it auto config again
    make -C "${LINUX_SRC_DIR}" $(get_make_args) olddefconfig
    
    if ! make -C "${LINUX_SRC_DIR}" $(get_make_args) -j"${NUM_JOBS}" 2>&1 | tee "${build_log}"; then
        log_error "Build failed. See ${build_log} for details"
        exit 1
    fi

    log_info "Generating debug information"
    if [[ ${USE_LLVM} -eq 1 ]]; then
        "${LLVM_READELF}" -a "${BUILD_DIR}/vmlinux" >"${BUILD_DIR}/vmlinux.readelf.txt"
    else
        "${GNU_READELF}" -a "${BUILD_DIR}/vmlinux" >"${BUILD_DIR}/vmlinux.readelf.txt"
    fi

    log_info "Generating compile_commands.json"
    cd "${LINUX_SRC_DIR}"
    python3 scripts/clang-tools/gen_compile_commands.py

    log_info "Generating rust-project.json for rust-analyzer"
    # Set required environment variables
    export RUSTC
    export BINDGEN=$(command -v bindgen)
    export CC="${CLANG}"
    export RUST_LIB_SRC
    cmd="make -C ${LINUX_SRC_DIR} $(get_make_args) rust-analyzer"
    echo "${cmd}"
    eval "${cmd}"

    # install modules to build directory
    make -C "${LINUX_SRC_DIR}" $(get_make_args) modules_install INSTALL_MOD_PATH="${BUILD_DIR}/modules-install"

    # install headers to build
    make -C "${LINUX_SRC_DIR}" ARCH="$(to_linux_arch "${ARCH}")" INSTALL_HDR_PATH="${BUILD_DIR}/usr" headers_install

    log_info "Build completed successfully"
}

install_bindgen() {
    log_info "Installing bindgen-cli"
    cargo install --locked bindgen-cli
}

run_rust_tests() {
    log_info "Running Rust tests"
    make -C "${LINUX_SRC_DIR}" $(get_make_args) rusttest
}

generate_rust_docs() {
    log_info "Generating Rust documentation"
    make -C "${LINUX_SRC_DIR}" $(get_make_args) rustdocs
}

build_rootfs() {
    log_info "Building rootfs"
    build_nix_rootfs
}

find_link_file() {
    local file=$1
    if [[ -L "${file}" ]]; then
        echo "$(readlink -f "${file}")"
    else
        echo "${file}"
    fi
}
build_libbpf() {
    log_info "Building libbpf using kernel build system for ${ARCH}"

    local linux_arch
    linux_arch=$(to_linux_arch "${ARCH}")

    local make_args="ARCH=${linux_arch} CROSS_COMPILE=${CROSS_COMPILE}"

    if [[ ${USE_LLVM} -eq 1 ]]; then
        make_args+=" LLVM=1 CC=${CLANG} LD=${LLD} AR=${LLVM_AR} NM=${LLVM_NM} STRIP=${LLVM_STRIP} OBJDUMP=${LLVM_OBJDUMP} READELF=${LLVM_READELF}"
        if [[ "${ARCH}" == "loongarch64" ]]; then
            make_args+=" KCFLAGS=--target=loongarch64-unknown-linux-gnu"
        elif [[ "${ARCH}" == "aarch64" ]]; then
            make_args+=" KCFLAGS=--target=aarch64-unknown-linux-gnu"
        fi
    fi

    # enter the libbpf path
    cd "${LINUX_SRC_DIR}/tools/lib/bpf"
    # run make with the make_args
    make clean
    make ${make_args}

    file "$(find_link_file "${LINUX_SRC_DIR}/tools/lib/bpf/libbpf.so")"
    file "$(find_link_file "${LINUX_SRC_DIR}/tools/lib/bpf/libbpf.a")"

    log_info "libbpf built. Artifacts are in ${LINUX_SRC_DIR}/tools/lib/bpf/"
}

run_rust_kunit_tests() {
    log_info "Running Rust KUnit (doctest) tests for ${ARCH}"
    local kunit_py="${LINUX_SRC_DIR}/tools/testing/kunit/kunit.py"
    if [[ ! -f "$kunit_py" ]]; then
        die "kunit.py not found at $kunit_py"
    fi
    # Ensure python3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        die "python3 is required to run kunit.py"
    fi
    # Run kunit.py with required options
    (cd "${LINUX_SRC_DIR}" && \
        python3 tools/testing/kunit/kunit.py run \
            --make_options "LLVM=1" \
            --arch="${ARCH}" \
            --kconfig_add CONFIG_RUST=y \
            --kconfig_add CONFIG_KUNIT=y \
            --kconfig_add CONFIG_RUST_KERNEL_DOCTESTS=y)
}

get_make_args_gcc() {
    local args="O=${BUILD_DIR} ARCH=$(to_linux_arch "${ARCH}") CROSS_COMPILE=${CROSS_COMPILE}"
    args+=" LLVM=0"
    args+=" CC=${GNU_GCC}"
    args+=" LD=${GNU_LD}"
    args+=" AR=${GNU_AR}"
    args+=" NM=${GNU_NM}"
    args+=" STRIP=${GNU_STRIP}"
    args+=" OBJDUMP=${GNU_OBJDUMP}"
    args+=" READELF=${GNU_READELF}"
    echo "${args}"
}

build_ebpf_kernel_samples() {
    log_info "Building eBPF kernel samples with static linking"
    cd "${LINUX_SRC_DIR}/samples/bpf"
    args=$(get_make_args_gcc)
    # args+=" V=1"
    echo "args: ${args}"
    make -C "${LINUX_SRC_DIR}/samples/bpf" ${args}
    log_info "ebpf kernel samples built with static linking"
}

show_help() {
    # Color codes
    local RESET="\033[0m"
    local BOLD="\033[1m"
    local WHITE="\033[37m"
    local YELLOW="\033[33m"
    local GREEN="\033[32m"
    local CYAN="\033[36m"

    echo -e "${BOLD}${WHITE}Linux Kernel Development Bootstrap${RESET}"
    echo -e "${BOLD}wheatfox (wheatfox17@.icloud.com) ${RESET}\n"

    echo -e "${BOLD}${YELLOW}Usage:${RESET}"
    echo "    $0 [command]"
    echo

    echo -e "${BOLD}${YELLOW}Commands:${RESET}"
    echo -e "    ${BOLD}${GREEN}help${RESET}              Show this help message"
    echo -e "    ${BOLD}${GREEN}def${RESET}               Run defconfig and initialize build"
    echo -e "    ${BOLD}${GREEN}clean${RESET}             Clean the build artifacts"
    echo -e "    ${BOLD}${GREEN}menu${RESET}              Run kernel menuconfig"
    echo -e "    ${BOLD}${GREEN}save${RESET}              Save current config as defconfig"
    echo -e "    ${BOLD}${GREEN}kernel${RESET}            Build the kernel (requires def first)"
    echo -e "    ${BOLD}${GREEN}rootfs${RESET}            Build the root filesystem using Nix"
    echo -e "    ${BOLD}${GREEN}libbpf${RESET}            Build libbpf library for cross compilation"
    echo -e "    ${BOLD}${GREEN}status${RESET}            Show build status and configuration"
    echo -e "    ${BOLD}${GREEN}check${RESET}             Check build dependencies"
    echo -e "    ${BOLD}${GREEN}install-bindgen${RESET}   Install bindgen-cli"
    echo -e "    ${BOLD}${GREEN}rust-test${RESET}         Run Rust tests"
    echo -e "    ${BOLD}${GREEN}rust-kunit-test${RESET}   Run Rust KUnit (doctest) tests"
    echo -e "    ${BOLD}${GREEN}rust-docs${RESET}         Generate Rust documentation"
    echo

    echo -e "${BOLD}${YELLOW}Build Options:${RESET}"
    echo -e "    ${BOLD}${CYAN}ARCH=${RESET}loongarch64|aarch64  Select target architecture (default: loongarch64)"
    echo -e "    ${BOLD}${CYAN}USE_LLVM=${RESET}0|1     Enable/disable LLVM toolchain (default: 1)"
    echo -e "    ${BOLD}${CYAN}LLVM_HOME=${RESET}<path>  Set custom LLVM tools path"
    echo

    echo -e "${BOLD}${YELLOW}Examples:${RESET}"
    echo "    $0 def                    # Configure kernel"
    echo "    $0 kernel                 # Build kernel with LLVM"
    echo "    ARCH=aarch64 $0 kernel      # Build kernel for ARM64"
    echo "    USE_LLVM=0 $0 kernel      # Build kernel with GNU toolchain"
    echo "    LLVM_HOME=/opt/llvm $0    # Use custom LLVM path"
    echo

    echo -e "${BOLD}${YELLOW}Toolchain:${RESET}"
    echo "    LLVM: Uses clang ${LLVM_VERSION:-18+} for kernel compilation"
    echo "    GNU:  Uses ${GNU_PREFIX} toolchain"
    echo

    echo -e "${BOLD}${YELLOW}Current Configuration:${RESET}"
    echo "    Architecture:  ${ARCH}"
    echo "    Target:        ${TARGET_DEFCONFIG}"
    echo "    Jobs:          ${NUM_JOBS}"
    echo
}

get_compiler_details() {
    if [[ ${USE_LLVM} -eq 1 ]]; then
        "${CLANG}" --version
    else
        "${GNU_GCC}" --version
    fi
}

show_status() {
    log_info "Build Status:"
    echo "  Kernel Version: linux-${CHOSEN}"
    echo "  Architecture: ${ARCH}"
    echo "  Compiler: $(get_compiler_details)"
    echo "  Host Nix: $(nix --version)"
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

# Function to find the closest matching command
find_closest_command() {
    local input=$1
    local min_distance=999
    local closest_command=""
    local commands=("help" "def" "clean" "menu" "save" "kernel" "rootfs" "libbpf" "status" "check" "install-bindgen" "rust-test" "rust-kunit-test" "rust-docs")

    for cmd in "${commands[@]}"; do
        # Calculate Levenshtein distance
        local distance=$(echo "$input" | awk -v cmd="$cmd" '
            function min(a, b) { return a < b ? a : b }
            function levenshtein(s1, s2,    l1, l2, i, j, m, n, d) {
                l1 = length(s1)
                l2 = length(s2)
                for (i = 0; i <= l1; i++) d[i,0] = i
                for (j = 0; j <= l2; j++) d[0,j] = j
                for (i = 1; i <= l1; i++) {
                    for (j = 1; j <= l2; j++) {
                        m = (substr(s1, i, 1) == substr(s2, j, 1)) ? 0 : 1
                        d[i,j] = min(min(d[i-1,j] + 1, d[i,j-1] + 1), d[i-1,j-1] + m)
                    }
                }
                return d[l1,l2]
            }
            { print levenshtein($0, cmd) }
        ')
        
        if [ "$distance" -lt "$min_distance" ]; then
            min_distance=$distance
            closest_command=$cmd
        fi
    done

    echo "$closest_command"
}

main() {
    # Initialize environment and exit on any error
    setup_workspace || exit 1
    # init_submodules
    check_rust || exit 1
    setup_toolchain || exit 1
    
    case "${1:-help}" in
    help | -h | --help) show_help ;;
    def) run_defconfig ;;
    clean) clean_build ;;
    menu) run_menuconfig ;;
    save) save_defconfig ;;
    kernel) build_kernel ;;
    rootfs) build_rootfs ;;
    libbpf) build_libbpf ;;
    status) show_status ;;
    check) check_build_env ;;
    ebpf-kernel-samples) build_ebpf_kernel_samples ;;
    install-bindgen) install_bindgen ;;
    rust-test) run_rust_tests ;;
    rust-kunit-test) run_rust_kunit_tests ;;
    rust-docs) generate_rust_docs ;;
    *)
        log_error "Unknown command: ${1}"
        closest=$(find_closest_command "${1}")
        if [ -n "$closest" ]; then
            log_info "Did you mean: $0 $closest ?"
        fi
        show_help
        ;;
    esac
}

main "$@"

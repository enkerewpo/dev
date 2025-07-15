#!/usr/bin/env bash
set -e

COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"

function info() {
    echo -e "${COLOR_GREEN}${COLOR_BOLD}[INFO]${COLOR_RESET} $1"
}

function error() {
    echo -e "${COLOR_RED}${COLOR_BOLD}[ERROR]${COLOR_RESET} $1"
}

if [ "$(uname -m)" != "x86_64" ]; then
    error "This script is only for x64 machines"
    exit 1
fi

if [ -z "$(nixos-version)" ]; then
    error "This script is only for NixOS"
    exit 1
fi
info "NixOS version: $(nixos-version), Linux kernel version: $(uname -r)"

# check if the ecc-rs is installed
if [ ! -x "$(command -v ecc-rs)" ]; then
    error "ecc-rs is not installed, please use nix-env -iA nixos.ecc to install it"
    exit 1
fi
info "ecc-rs is located at $(which ecc-rs)"

# check if the ecli is installed
if [ ! -x "$(command -v ./ecli)" ]; then
    error "ecli is not installed, please wget https://aka.pw/bpf-ecli -O ecli && chmod +x ./ecli"
    exit 1
fi
info "ecli is located at $(which ./ecli)"

# build the ebpf program
ecc-rs test_kprobe.bpf.c
sudo ./ecli run package.json
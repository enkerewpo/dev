{ pkgs ? import <nixpkgs> {} }:

let
  crossPkgs = import <nixpkgs> {
    crossSystem = {
      config = "loongarch64-unknown-linux-gnu";
      libc = "glibc";
      withTLS = true;
      withLLVM = true;
    };
  };
in
crossPkgs.buildEnv {
  name = "loongarch64-rootfs";
  paths = with crossPkgs; [
    bash
    coreutils
    util-linux
    systemd
    udev
    kmod
    iproute2
    ethtool
    dhcpcd
    openssh
    vim
    curl
    wget
    git
    gcc
    binutils
    gnumake
    pkg-config
    rustc
    cargo
  ];
} 
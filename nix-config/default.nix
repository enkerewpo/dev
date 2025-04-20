{ pkgs }:

pkgs.buildEnv {
  name = "loongarch64-rootfs";
  paths = with pkgs; [
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
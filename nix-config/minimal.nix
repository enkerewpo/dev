{ pkgs }:

let
  util-linux = pkgs.util-linux.overrideAttrs (super: {
    buildInputs = super.buildInputs ++ [ pkgs.pkg-config ];
  });

in pkgs.buildEnv {
  name = "rootfs";
  paths = with pkgs; [
    busybox
    coreutils
    bash
    zsh
    curl
    findutils
    gnugrep
    gnused
    sudo
    gnutar
    gzip
    binutils
    glibc
    pciutils
    vim
    perf-tools
    strace
    file
    rt-tests
    tmux
    util-linux
    htop
    ncurses
    dhcpcd
    iproute2
    iputils
    bpftools
    libbpf
    procps
    hwinfo
    clang
    lld
    gnumake
    binutils
    llvm
    bpftools
  ];

  extraOutputsToInstall = [
    "bin"
    "sbin"
    "lib"
    "etc"
    "man"
    "share"
    "usr"
    "usr/bin"
    "usr/sbin"
    "usr/lib"
    "usr/share"
    "usr/share/man"
    "usr/lib"
    "usr/include"
  ];

  pathsToLink = [
    "/bin"
    "/sbin"
    "/lib"
    "/share"
    "/etc"
    "/share/man"
    "/usr"
    "/usr/bin"
    "/usr/sbin"
    "/usr/lib"
    "/usr/share"
    "/usr/share/man"
    "/usr/lib"
    "/usr/include"
  ];

  postBuild = ''
    #!/bin/bash

    mkdir -p $out/{dev,proc,sys,run,tmp,var/log,var/tmp}
    chmod 1777 $out/tmp $out/var/tmp
    mkdir -p $out/var/empty
    chmod 0555 $out/var/empty
    mkdir -p $out/etc
    echo "root::0:0:root:/root:/bin/bash" > $out/etc/passwd
    echo "root:x:0:" > $out/etc/group

    cat <<EOF > $out/etc/os-release
    NAME=NixOS
    ID=nixos
    VERSION="wheatfox-20250421"
    VERSION_CODENAME=wheatfox
    PRETTY_NAME="NixOS wheatfox-20250421"
    LOGO="nix-snowflake"
    HOME_URL="https://nixos.org/"
    DOCUMENTATION_URL="https://nixos.org/learn.html"
    SUPPORT_URL="https://nixos.org/community.html"
    BUG_REPORT_URL="https://github.com/NixOS/nixpkgs/issues"
    EOF

    mkdir -p $out/etc/init.d
    cat <<EOF > $out/etc/init.d/rcS
    #!/bin/bash
    mount sys /sys -t sysfs
    mount proc /proc -t proc
    mount dev /dev -t devtmpfs
    mount run /run -t tmpfs
    EOF
    chmod +x $out/etc/init.d/rcS
  '';
}

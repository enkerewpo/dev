{ pkgs }:

let
  qemu_loongarch = (pkgs.qemu_kvm.override {
    hostCpuOnly = true;
    alsaSupport = false;
    pulseSupport = false;
    sdlSupport = false;
    jackSupport = false;
    gtkSupport = false;
    vncSupport = false;
    smartcardSupport = false;
    spiceSupport = false;
    ncursesSupport = false;
    libiscsiSupport = false;
    tpmSupport = false;
    numaSupport = false;
    seccompSupport = false;
    guestAgentSupport = false;
    minimal = true;
  }).overrideAttrs (super: {
    buildInputs = super.buildInputs ++ [ pkgs.git pkgs.dtc pkgs.pkg-config ];
  });

in pkgs.buildEnv {
  name = "loongarch64-rootfs";
  paths = with pkgs; [
    busybox
    coreutils
    bash
    curl
    findutils
    gnugrep
    gnused
    gnutar
    gzip
    binutils
    fastfetch
    glibc
    pciutils
    vim
    systemd
    perf-tools
    file
    qemu_loongarch
    rt-tests
    util-linux
    htop
    ncurses
    nix
    glib
    python3
    python3.pkgs.setuptools
    python3.pkgs.wheel
    dhcpcd
    iproute2
    iputils
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

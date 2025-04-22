{ pkgs ? import <nixpkgs> }:

pkgs.buildEnv {
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
    glibc
    zlib
    pciutils
    vim
    perf-tools
  ];
  
  extraOutputsToInstall = [ "dev" "bin" "out" ];
  pathsToLink = [ "/bin" "/sbin" "/lib" "/share" ];
  buildInputs = with pkgs; [ gcc binutils ];
  postBuild = ''
    mkdir -p $out/{dev,proc,sys,run,tmp,var/log,var/tmp}
    chmod 1777 $out/tmp $out/var/tmp
    mkdir -p $out/var/empty
    chmod 0555 $out/var/empty
    mkdir -p $out/etc
    echo "root::0:0:root:/root:/bin/bash" > $out/etc/passwd
    echo "root:x:0:" > $out/etc/group
    
    # Add NixOS os-release information
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
    
    # run mount sys /sys -t sysfs and mount proc /proc -t proc in rcS
    # we first need to create the rcS script
    mkdir -p $out/etc/init.d
    cat <<EOF > $out/etc/init.d/rcS
#!/bin/bash
mount sys /sys -t sysfs
mount proc /proc -t proc
EOF
    chmod +x $out/etc/init.d/rcS
  '';
} 
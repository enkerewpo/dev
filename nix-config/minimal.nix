{ pkgs }:

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
    glib
    iproute2
    zlib
    pciutils
    vim
    perf-tools
    python3
    meson
    ninja
    pkg-config
    libtool
    autoconf
    automake
    gcc
    file
    dtc
  ];

  extraOutputsToInstall = [ "dev" "bin" "out" "man" ];
  pathsToLink = [ "/bin" "/sbin" "/lib" "/share" "/etc" "/share/man" ];
  buildInputs = with pkgs; [ gcc binutils ];
  postBuild = builtins.readFile ./post-build.sh;
} 
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
    zlib
    pciutils
    vim
    perf-tools
    python3
    file
    qemu_kvm
    systemd
  ];

  extraOutputsToInstall = [ "dev" "bin" "out" "man" ];
  pathsToLink = [ "/bin" "/sbin" "/lib" "/share" "/etc" "/share/man" ];
  buildInputs = with pkgs; [ gcc binutils ];
  postBuild = builtins.readFile ./post-build.sh;
} 
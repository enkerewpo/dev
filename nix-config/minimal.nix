{ pkgs }:

let qemu_kvm_loongarch = pkgs.qemu_kvm.override {
  minimal = true;
};

in

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
    glib
    binutils
    fastfetch
    htop
    glibc
    zlib
    pciutils
    vim
    perf-tools
    python3
    file
    qemu_kvm_loongarch
    libvirt
    rt-tests
    OVMF
  ];

  extraOutputsToInstall = [ "dev" "bin" "out" "man" ];
  pathsToLink = [ "/bin" "/sbin" "/lib" "/share" "/etc" "/share/man" ];
  buildInputs = with pkgs; [ gcc binutils ];
  postBuild = builtins.readFile ./post-build.sh;
} 
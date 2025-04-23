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
    binutils
    fastfetch
    glibc
    zlib
    pciutils
    vim
    systemd
    perf-tools
    file
    qemu_kvm_loongarch
    rt-tests
    libvirt
  ];

  extraOutputsToInstall = [ "dev" "bin" "out" "man" ];
  pathsToLink = [ "/bin" "/sbin" "/lib" "/share" "/etc" "/share/man" ];
  buildInputs = with pkgs; [ gcc binutils ];
  postBuild = builtins.readFile ./post-build.sh;
} 
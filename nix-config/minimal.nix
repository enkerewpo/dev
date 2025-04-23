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
    buildInputs = super.buildInputs ++ [
      pkgs.git
      pkgs.dtc
      pkgs.pkg-config
    ];
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
    zlib
    pciutils
    vim
    systemd
    perf-tools
    file
    qemu_loongarch
    rt-tests
    libvirt
  ];

  extraOutputsToInstall = [ "dev" "bin" "out" "man" ];
  pathsToLink = [ "/bin" "/sbin" "/lib" "/share" "/etc" "/share/man" ];
  postBuild = builtins.readFile ./post-build.sh;
}

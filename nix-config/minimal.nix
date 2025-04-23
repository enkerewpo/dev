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

  # Create systemd configuration files
  systemdConfig = pkgs.writeText "systemd.conf" (builtins.readFile ./systemd/system.conf);
  gettyService = pkgs.writeText "getty-tty1.service" (builtins.readFile ./systemd/services/getty-tty1.service);
  serialGettyService = pkgs.writeText "serial-getty.service" (builtins.readFile ./systemd/services/serial-getty.service);
  shellService = pkgs.writeText "shell.service" (builtins.readFile ./systemd/services/shell.service);
  rescueService = pkgs.writeText "rescue.service" (builtins.readFile ./systemd/services/rescue.service);
  defaultTarget = pkgs.writeText "default.target" (builtins.readFile ./systemd/targets/default.target);
  multiUserTarget = pkgs.writeText "multi-user.target" (builtins.readFile ./systemd/targets/multi-user.target);
  basicTarget = pkgs.writeText "basic.target" (builtins.readFile ./systemd/targets/basic.target);
  socketsTarget = pkgs.writeText "sockets.target" (builtins.readFile ./systemd/targets/sockets.target);
  sysinitTarget = pkgs.writeText "sysinit.target" (builtins.readFile ./systemd/targets/sysinit.target);
  localFsTarget = pkgs.writeText "local-fs.target" (builtins.readFile ./systemd/targets/local-fs.target);
  localFsPreTarget = pkgs.writeText "local-fs-pre.target" (builtins.readFile ./systemd/targets/local-fs-pre.target);
  rescueTarget = pkgs.writeText "rescue.target" (builtins.readFile ./systemd/targets/rescue.target);
  gettyTarget = pkgs.writeText "getty.target" (builtins.readFile ./systemd/targets/getty.target);
  serialGettyTarget = pkgs.writeText "serial-getty.target" (builtins.readFile ./systemd/targets/serial-getty.target);

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

# Create systemd configuration directory
mkdir -p $out/etc/systemd

# Copy systemd configuration
cp ${systemdConfig} $out/etc/systemd/system.conf

# Create systemd service directory
mkdir -p $out/etc/systemd/system
mkdir -p $out/etc/systemd/user

# Create systemd journal directory
mkdir -p $out/var/log/journal
chmod 755 $out/var/log/journal

# Copy service files
cp ${gettyService} $out/etc/systemd/system/getty@tty1.service
cp ${serialGettyService} $out/etc/systemd/system/serial-getty@.service
cp ${shellService} $out/etc/systemd/system/shell.service
cp ${rescueService} $out/etc/systemd/system/rescue.service

# Copy target files
cp ${defaultTarget} $out/etc/systemd/system/default.target
cp ${multiUserTarget} $out/etc/systemd/system/multi-user.target
cp ${basicTarget} $out/etc/systemd/system/basic.target
cp ${socketsTarget} $out/etc/systemd/system/sockets.target
cp ${sysinitTarget} $out/etc/systemd/system/sysinit.target
cp ${localFsTarget} $out/etc/systemd/system/local-fs.target
cp ${localFsPreTarget} $out/etc/systemd/system/local-fs-pre.target
cp ${rescueTarget} $out/etc/systemd/system/rescue.target
cp ${gettyTarget} $out/etc/systemd/system/getty.target
cp ${serialGettyTarget} $out/etc/systemd/system/serial-getty.target

# Set proper permissions
chmod 644 $out/etc/systemd/system.conf
chmod 644 $out/etc/systemd/system/default.target
chmod 644 $out/etc/systemd/system/multi-user.target
chmod 644 $out/etc/systemd/system/basic.target
chmod 644 $out/etc/systemd/system/sockets.target
chmod 644 $out/etc/systemd/system/sysinit.target
chmod 644 $out/etc/systemd/system/local-fs.target
chmod 644 $out/etc/systemd/system/local-fs-pre.target
chmod 644 $out/etc/systemd/system/rescue.target
chmod 644 $out/etc/systemd/system/rescue.service
chmod 644 $out/etc/systemd/system/getty@tty1.service
chmod 644 $out/etc/systemd/system/serial-getty@.service
chmod 644 $out/etc/systemd/system/getty.target
chmod 644 $out/etc/systemd/system/serial-getty.target
chmod 644 $out/etc/systemd/system/shell.service 
  '';
}

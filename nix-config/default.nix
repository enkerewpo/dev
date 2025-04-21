{ pkgs }:

pkgs.buildEnv {
  name = "loongarch64-rootfs";
  paths = with pkgs; [
    busybox
    coreutils
    bash
    nix
    curl
    findutils
    gawk
    gnugrep
    gnused
    gnutar
    gzip
    gcc
    binutils
    gnumake
    iproute2
    iptables
    glibc
    zlib
    openssl
    neofetch
    # systemd
    # rt-tests
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
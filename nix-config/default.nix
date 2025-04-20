{ pkgs }:

pkgs.buildEnv {
  name = "loongarch64-rootfs";
  paths = with pkgs; [
    # Core system utilities
    busybox
    coreutils
    bash
    nix
    curl
    
    # Basic system tools
    findutils
    gawk
    gnugrep
    gnused
    gnutar
    gzip
    
    # Development tools
    gcc
    binutils
    gnumake
    
    # Network tools
    iproute2
    iptables
    
    # Essential libraries
    glibc
    zlib
    openssl
  ];
  
  # Add any additional configuration here
  extraOutputsToInstall = [ "dev" "bin" "out" ];
  
  # Ensure proper permissions
  pathsToLink = [ "/bin" "/sbin" "/lib" "/share" ];
  
  # Set up basic directory structure
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
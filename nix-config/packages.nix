{ pkgs }:

with pkgs; [
  # programs
  vim
  htop
  curl
  wget
  fastfetch
  iproute2
  iputils
  netcat
  strace
  procps
  sysstat
  e2fsprogs
  gzip
  bzip2
  xz
  unzip
  tree
  nix
  pciutils
  file
  pkg-config
  elfutils
  zlib
  lsof
  # libs
  glibc
  libelf
  zlib
  zstd
  bpftools
  # bpftrace
  # bpftop
] 
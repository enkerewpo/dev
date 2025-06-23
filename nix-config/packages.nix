{ pkgs }:

let 
  busybox_static = pkgs.busybox.overrideAttrs (oldAttrs: {
    enableStatic = true;
  });
in
with pkgs; [
  busybox_static
  vim
  htop
  tmux
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
] 
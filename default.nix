{ pkgs ? import <nixpkgs> {} }:

let
  loongarch64Pkgs = pkgs.pkgsCross.loongarch64-linux;
  rootfsContent = import ./nix-config/minimal.nix { pkgs = loongarch64Pkgs; };
  storePaths = pkgs.lib.unique (pkgs.lib.concatMap (pkg: 
    [pkg] ++ (pkg.runtimeDependencies or [])
  ) [rootfsContent]);
  rootfsImage = pkgs.callPackage <nixpkgs/nixos/lib/make-ext4-fs.nix> ({
    storePaths = storePaths;
    volumeLabel = "NIXOS_LOONGARCH64";
  });
in {
  rootfs = rootfsContent;
  image = rootfsImage;
} 
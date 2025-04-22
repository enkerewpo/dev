{
  description = "Loongarch64 Linux rootfs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nur.url = "github:nix-community/NUR";
  };

  outputs = { self, nixpkgs, nur, flake-utils }: let 
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    loongarch64Pkgs = pkgs.pkgsCross.loongarch64-linux;
    rootfsContent = import ./nix-config/default.nix { pkgs = loongarch64Pkgs; };
    storePaths = pkgs.lib.unique (pkgs.lib.concatMap (pkg: 
      [pkg] ++ (pkg.runtimeDependencies or [])
    ) [rootfsContent]);
    rootfsImage = pkgs.callPackage <nixpkgs/nixos/lib/make-ext4-fs.nix> ({
      storePaths = storePaths;
      volumeLabel = "NIXOS_LOONGARCH64";
    });
  in {
    packages.${system} = {
      default = rootfsImage;
      rootfs = rootfsContent;
    };
    
    devShells.${system}.default = import ./nix-config/shell.nix { pkgs = pkgs; };
  };
} 
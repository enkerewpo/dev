{
  description = "Loongarch64 Linux rootfs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    
    # Use the built-in Loongarch64 cross-compilation support
    loongarch64Pkgs = pkgs.pkgsCross.loongarch64-linux;
  in {
    packages.${system}.default = import ./nix-config/default.nix { pkgs = loongarch64Pkgs; };
    devShells.${system}.default = import ./nix-config/shell.nix { pkgs = pkgs; };
  };
} 
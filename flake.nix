{
  description = "Loongarch64 Linux rootfs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    
    # Loongarch64 cross-compilation configuration
    loongarch64Pkgs = import nixpkgs {
      inherit system;
      crossSystem = {
        config = "loongarch64-unknown-linux-gnu";
        libc = "glibc";
        withTLS = true;
        withLLVM = true;
      };
    };
  in {
    packages.${system}.default = import ./nix-config/default.nix { pkgs = loongarch64Pkgs; };
    devShells.${system}.default = import ./nix-config/shell.nix { pkgs = pkgs; };
  };
} 
{
  description = "Loongarch64 Linux rootfs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = import ./nix-config/default.nix { pkgs = nixpkgs.legacyPackages.x86_64-linux; };
    devShells.x86_64-linux.default = import ./nix-config/shell.nix { pkgs = nixpkgs.legacyPackages.x86_64-linux; };
  };
} 
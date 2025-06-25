let
  pkgs = import ../nixpkgs {};
  cross = import ../nixpkgs {
    crossSystem = { config = "loongarch64-unknown-linux-gnu"; };
  };
in
pkgs.mkShell {
  buildInputs = [
    cross.buildPackages.gcc
    cross.buildPackages.binutils
    cross.buildPackages.glibc
    cross.buildPackages.glibc.dev
    cross.buildPackages.libgcc
    cross.buildPackages.libelf
    cross.buildPackages.elfutils
    cross.buildPackages.libffi
    cross.buildPackages.zlib
    cross.buildPackages.libz
  ];
}
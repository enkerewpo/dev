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
    cross.buildPackages.libgcc
    cross.buildPackages.libelf
    cross.buildPackages.elfutils
    cross.buildPackages.libffi
    cross.buildPackages.zlib
    cross.buildPackages.libz

    pkgs.llvmPackages.llvm
    pkgs.llvmPackages.libclang
    pkgs.llvmPackages.clang-unwrapped
    pkgs.llvmPackages.clang-unwrapped.dev
    pkgs.llvmPackages.clang-unwrapped.lib
    pkgs.llvmPackages.clang-unwrapped.lib.dev
    pkgs.libffi
    pkgs.zlib
    pkgs.libedit
    pkgs.libz
  ];
  shellHook = ''
    COLOR_YELLOW='\033[1;33m'
    COLOR_RESET='\033[0m'
    echo -e "\n$COLOR_YELLOW This is a dev shell environment for loongarch64, you can then run ./bootstrap.sh commands to build stuff. $COLOR_RESET"
  '';
}

# ./bootstrap.sh ebpf-samples
{ pkgs ? import ../nixpkgs {} }:

let
  crossSystems = {
    aarch64 = {
      config = "aarch64-unknown-linux-gnu";
      system = "aarch64-linux";
    };
    armv7l = {
      config = "armv7l-unknown-linux-gnueabihf";
      system = "armv7l-linux";
    };
    riscv64 = {
      config = "riscv64-unknown-linux-gnu";
      system = "riscv64-linux";
    };
    x86_64 = {
      config = "x86_64-unknown-linux-gnu";
      system = "x86_64-linux";
    };
    loongarch64 = {
      config = "loongarch64-unknown-linux-gnu";
      system = "loongarch64-linux";
    };
  };

  mkCrossPkgs = system: import ../nixpkgs {
    crossSystem = system;
  };

  crossPkgs = builtins.mapAttrs (name: system: {
    gcc = mkCrossPkgs system;
    clang = mkCrossPkgs (system // { useLLVM = true; });
  }) crossSystems;

  checkBinary = pkgs: binary: pkgs.runCommand "check-binary" {} ''
    file ${binary}/bin/cyclictest > $out
  '';

in {
  rt-tests-cross = builtins.mapAttrs (name: pkgs: {
    gcc = pkgs.gcc.rt-tests;
    clang = pkgs.clang.rt-tests;
  }) crossPkgs;

  binary-checks = builtins.mapAttrs (name: pkgs: {
    gcc = checkBinary pkgs.gcc pkgs.gcc.rt-tests;
    clang = checkBinary pkgs.clang pkgs.clang.rt-tests;
  }) crossPkgs;

  shell = pkgs.mkShell {
    buildInputs = with pkgs; [
      gcc
      clang
      gnumake
      pkg-config
    ];
  };
}

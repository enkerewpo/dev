{ pkgs }:

builtins.trace "[wheatfox] in shell.nix"

pkgs.mkShell {
  buildInputs = with pkgs; [
    nix
    git
    gnumake
    gcc
    binutils
    pkg-config
  ];
} 
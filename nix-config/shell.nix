{ pkgs ? import <nixpkgs> {} }:

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
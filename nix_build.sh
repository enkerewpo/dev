export NIXPKGS_ALLOW_BROKEN=1
export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

nix-build aarch64.nix --show-trace --log-format bar -A image --out-link image
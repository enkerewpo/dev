export NIXPKGS_ALLOW_BROKEN=1
export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

ARCH=$1
if [ "$ARCH" == "aarch64" ]; then
    nix-build aarch64.nix --show-trace --log-format bar -A image --out-link image
elif [ "$ARCH" == "loongarch64" ]; then
    nix-build loongarch.nix --show-trace --log-format bar -A image --out-link image
else
    echo "Invalid architecture: $ARCH"
    exit 1
fi
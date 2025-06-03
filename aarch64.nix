let system = "aarch64-linux";
in {
  image = (import ../nixpkgs/nixos {
    configuration = { pkgs, ... }: {
      nixpkgs.crossSystem.system = system;
      nixpkgs.overlays = [
        (import ./overlays/linux-local.nix)
      ];
      imports = [
        ../nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix
      ];
      sdImage.compressImage = false;
      boot.loader.grub.enable = false;
      boot.kernel.enable = false;
      boot.kernelPackages = pkgs.linuxKernel.packages.linux_local;
    };
  }).config.system.build.sdImage;
}

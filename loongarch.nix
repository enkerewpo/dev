let system = "loongarch64-linux";
in {
  image = (import ../nixpkgs/nixos {
    configuration = { pkgs, ... }: {
      nixpkgs.crossSystem.system = system;
      nixpkgs.overlays = [
        (import ./overlays/linux-local.nix)
      ];
      imports = [
        ../nixpkgs/nixos/modules/installer/sd-card/sd-image-loongarch64.nix
      ];
      sdImage.compressImage = false;
      boot.loader.grub.enable = false;
      boot.kernel.enable = false;
      boot.kernelPackages = pkgs.linuxKernel.packages.linux_local;
      boot.initrd.enable = false;
      boot.initrd.kernelModules = [];
      environment.systemPackages = import ./nix-config/packages.nix { inherit pkgs; };
      
      users.users = {
        wheatfox = {
          isNormalUser = true;
          description = "wheatfox";
          extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
          password = "1234";
        };
      };
      
      security.sudo.wheelNeedsPassword = false;
      services.getty.autologinUser = "wheatfox";
    };
  }).config.system.build.sdImage;
}


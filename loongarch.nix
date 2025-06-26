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
          shell = pkgs.bash;
        };
      };
      
      security.sudo.wheelNeedsPassword = false;
      services.getty.autologinUser = "wheatfox";
      
      # Configure bashrc for wheatfox user
      environment.etc."bashrc".text = ''
        # Source global definitions
        if [ -f /etc/bashrc ]; then
          . /etc/bashrc
        fi
        
        # Auto-mount and setup for eBPF programs
        if [ "$(whoami)" = "wheatfox" ]; then
          # Create mount point and mount vdb1
          sudo mkdir -p /mnt 2>/dev/null || true
          sudo mount /dev/vdb1 /mnt 2>/dev/null || true
          
          # Set LD_LIBRARY_PATH
          export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib64:/lib:/run/current-system/sw/lib:/usr/share/bpf
        fi
      '';
    };
  }).config.system.build.sdImage;
}


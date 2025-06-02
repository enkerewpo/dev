let system = "aarch64-linux";
in {
  image = (import ../nixpkgs/nixos {
    configuration = { ... }: {
      nixpkgs.crossSystem.system = system;
      imports = [
        ../nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix
        ../nixpkgs/nixos/modules/profiles/minimal.nix
      ];
      boot.isContainer = true;
    };
  }).config.system.build.sdImage;
}

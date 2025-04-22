{
  description = "Loongarch64 Linux rootfs";

  inputs = {
    nixpkgs.url = "github:enkerewpo/nixpkgs";
    nur.url = "github:nix-community/NUR";
  };

  outputs = { self, nixpkgs, nur }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    
    # Use the built-in Loongarch64 cross-compilation support
    loongarch64Pkgs = pkgs.pkgsCross.loongarch64-linux;

    # Create the rootfs content
    rootfsContent = import ./nix-config/default.nix { pkgs = loongarch64Pkgs; };

    # Get all store paths from the rootfs content
    storePaths = pkgs.lib.unique (pkgs.lib.concatMap (pkg: 
      [pkg] ++ (pkg.runtimeDependencies or [])
    ) [rootfsContent]);

    # Create a script to set up the rootfs structure
    setupRootfs = pkgs.writeScript "setup-rootfs.sh" ''
      #!/bin/sh
      set -e

      # Create basic directory structure
      mkdir -p ./bin ./sbin ./lib ./usr/bin ./usr/sbin ./usr/lib ./etc

      # Create symlinks for dynamic libraries
      ln -sf ${loongarch64Pkgs.glibc}/lib/ld-linux-loongarch64-lp64d.so.1 ./lib/ld-linux-loongarch64-lp64d.so.1
      ln -sf ${loongarch64Pkgs.glibc}/lib/libc.so.6 ./lib/libc.so.6
      ln -sf ${loongarch64Pkgs.glibc}/lib/libm.so.6 ./lib/libm.so.6
      ln -sf ${loongarch64Pkgs.glibc}/lib/libdl.so.2 ./lib/libdl.so.2
      ln -sf ${loongarch64Pkgs.glibc}/lib/librt.so.1 ./lib/librt.so.1
      ln -sf ${loongarch64Pkgs.glibc}/lib/libpthread.so.0 ./lib/libpthread.so.0

      # Create ld.so.conf
      echo "/lib" > ./etc/ld.so.conf
      echo "/usr/lib" >> ./etc/ld.so.conf

      # Create basic passwd and group files
      echo "root::0:0:root:/root:/bin/bash" > ./etc/passwd
      echo "root:x:0:" > ./etc/group

    '';

    # Create ext4 image
    rootfsImage = pkgs.callPackage <nixpkgs/nixos/lib/make-ext4-fs.nix> ({
      storePaths = storePaths;
      volumeLabel = "NIXOS_LOONGARCH64";
      populateImageCommands = ''
        # Run the setup script
        ${setupRootfs}
      '';
    });
  in {
    packages.${system} = {
      default = rootfsImage;
      rootfs = rootfsContent;
    };
    
    devShells.${system}.default = import ./nix-config/shell.nix { pkgs = pkgs; };
  };
} 
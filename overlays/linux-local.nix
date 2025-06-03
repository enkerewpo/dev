self: super: {
  linuxKernel = super.linuxKernel // {
    packages = super.linuxKernel.packages // {
      linux_local = (super.linuxKernel.manualConfig {
        version = "6.15.0-git-wheatfox";
        modDirVersion = "6.15.0";
        src = /home/wheatfox/tryredox/linux-dev/linux-git;
        configfile = /home/wheatfox/tryredox/linux-dev/build-arm64/.config;
        kernelPatches = [];
        extraMeta.branch = "6.15";
      }).overrideAttrs (old: {
        passthru = old.passthru // {
          extend = f: super.linuxKernel.packagesFor (super.linuxKernel.manualConfig {
            version = "6.15.0-git-wheatfox";
            modDirVersion = "6.15.0";
            src = /home/wheatfox/tryredox/linux-dev/linux-git;
            configfile = /home/wheatfox/tryredox/linux-dev/build-arm64/.config;
            kernelPatches = [];
            extraMeta.branch = "6.15";
          });
        };
      });
    };
  };
} 
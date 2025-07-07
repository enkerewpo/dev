self: super: {
  linuxKernel = super.linuxKernel // {
    packages = super.linuxKernel.packages // {
      linux_local = (super.linuxKernel.manualConfig {
        version = "6.16-git-wheatfox";
        modDirVersion = "6.16.0-rc4"; # 20250707
        src = ../linux-git;
        configfile = ../build/.config;
        kernelPatches = [];
        extraMeta.branch = "6.16";
      }).overrideAttrs (old: {
        passthru = old.passthru // {
          extend = f: super.linuxKernel.packagesFor (super.linuxKernel.manualConfig {
            version = "6.16-git-wheatfox";
            modDirVersion = "6.16.0-rc4"; # 20250707
            src = ../linux-git;
            configfile = ../build/.config;
            kernelPatches = [];
            extraMeta.branch = "6.16";
          });
        };
      });
    };
  };
} 
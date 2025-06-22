self: super: {
  linuxKernel = super.linuxKernel // {
    packages = super.linuxKernel.packages // {
      linux_local = (super.linuxKernel.manualConfig {
        version = "6.16-git-wheatfox";
        modDirVersion = "6.16.0-rc2";
        src = /home/wheatfox/tryredox/linux-dev/linux-git;
        configfile = /home/wheatfox/tryredox/linux-dev/build/.config;
        kernelPatches = [];
      }).overrideAttrs (old: {
        passthru = old.passthru // {
          extend = f: super.linuxKernel.packagesFor (super.linuxKernel.manualConfig {
            version = "6.16-git-wheatfox";
            modDirVersion = "6.16.0-rc2";
            src = /home/wheatfox/tryredox/linux-dev/linux-git;
            configfile = /home/wheatfox/tryredox/linux-dev/build/.config;
            kernelPatches = [];
          });
        };
      });
    };
  };
} 
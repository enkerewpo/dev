{ pkgs, system ? "loongarch64-linux" }:

let
  crossPkgs = pkgs.pkgsCross.${system};
  
  commonBuildInputs = with pkgs; [
    gcc
    binutils
    pkg-config
    cmake
    autoconf
    automake
    libtool
    gettext
  ];
  
  zlib-cross = crossPkgs.zlib.overrideAttrs (oldAttrs: {
    name = "zlib-${oldAttrs.version}-${system}";
    
    nativeBuildInputs = commonBuildInputs;
    
    outputs = [ "out" "dev" ];
    
    postInstall = ''
      mkdir -p $dev/lib/pkgconfig
      cat > $dev/lib/pkgconfig/zlib.pc << EOF
      prefix=$out
      exec_prefix=\''${prefix}
      libdir=\''${exec_prefix}/lib
      sharedlibdir=\''${libdir}
      includedir=\''${prefix}/include

      Name: zlib
      Description: zlib compression library
      Version: ${oldAttrs.version}

      Requires:
      Libs: -L\''${libdir} -L\''${sharedlibdir} -lz
      Cflags: -I\''${includedir}
      EOF
    '';
    
    meta = oldAttrs.meta // {
      description = "Cross-compiled zlib compression library for ${system}";
    };
  });
  
  zstd-cross = crossPkgs.zstd.overrideAttrs (oldAttrs: {
    name = "zstd-${oldAttrs.version}-${system}";
    
    nativeBuildInputs = commonBuildInputs;
    
    outputs = [ "out" "dev" ];
    
    cmakeFlags = [
      "-DZSTD_BUILD_STATIC=ON"
      "-DZSTD_BUILD_SHARED=ON"
      "-DZSTD_BUILD_PROGRAMS=OFF"
      "-DZSTD_BUILD_TESTS=OFF"
    ];
    
    postInstall = ''
      mkdir -p $dev/lib/pkgconfig
      cat > $dev/lib/pkgconfig/libzstd.pc << EOF
      prefix=$out
      exec_prefix=\''${prefix}
      libdir=\''${exec_prefix}/lib
      includedir=\''${prefix}/include

      Name: libzstd
      Description: fast lossless compression algorithm library
      URL: https://facebook.github.io/zstd/
      Version: ${oldAttrs.version}
      Libs: -L\''${libdir} -lzstd
      Cflags: -I\''${includedir}
      EOF
    '';
    
    meta = oldAttrs.meta // {
      description = "Cross-compiled zstd compression library for ${system}";
    };
  });
  
  libelf-cross = crossPkgs.elfutils.overrideAttrs (oldAttrs: {
    name = "libelf-${oldAttrs.version}-${system}";
    
    nativeBuildInputs = commonBuildInputs;
    
    outputs = [ "out" "dev" ];
    
    # Disable CMake build system and use autotools
    cmakeFlags = [];
    dontUseCmakeConfigure = true;
    
    # Configure flags for cross-compilation
    configureFlags = [
      "--enable-shared"
      "--enable-static"
      "--disable-debuginfod"
      "--disable-debuginfod-client"
      "--disable-libdebuginfod"
      "--disable-nls"
    ];
    
    postInstall = ''
      # Create pkg-config file for libelf
      mkdir -p $dev/lib/pkgconfig
      cat > $dev/lib/pkgconfig/libelf.pc << EOF
      prefix=$out
      exec_prefix=\''${prefix}
      libdir=\''${exec_prefix}/lib
      includedir=\''${prefix}/include

      Name: libelf
      Description: ELF object file access library
      Version: ${oldAttrs.version}
      Libs: -L\''${libdir} -lelf
      Cflags: -I\''${includedir}
      EOF
    '';
    
    meta = oldAttrs.meta // {
      description = "Cross-compiled libelf library for ${system}";
    };
  });

  cross-libs = pkgs.symlinkJoin {
    name = "cross-libs-${system}";
    paths = [ 
      zlib-cross.out 
      zlib-cross.dev 
      zstd-cross.out 
      zstd-cross.dev 
      libelf-cross.out 
      libelf-cross.dev 
    ];
    
    postBuild = ''
      mkdir -p $out/bin
      
      cat > $out/bin/pkg-config-wrapper << 'EOF'
      #!/bin/sh
      export PKG_CONFIG_PATH="$out/lib/pkgconfig:$PKG_CONFIG_PATH"
      exec ${pkgs.pkg-config}/bin/pkg-config "$@"
      EOF
      chmod +x $out/bin/pkg-config-wrapper
      
      cat > $out/bin/setup-env << 'EOF'
      #!/bin/sh
      export PKG_CONFIG_PATH="$out/lib/pkgconfig:$PKG_CONFIG_PATH"
      export LD_LIBRARY_PATH="$out/lib:$LD_LIBRARY_PATH"
      export LIBRARY_PATH="$out/lib:$LIBRARY_PATH"
      export C_INCLUDE_PATH="$out/include:$C_INCLUDE_PATH"
      export CPLUS_INCLUDE_PATH="$out/include:$CPLUS_INCLUDE_PATH"
      echo "Cross-compilation environment set up for ${system}"
      echo "Libraries available:"
      echo "  - zlib (static: libz.a, dynamic: libz.so)"
      echo "  - zstd (static: libzstd.a, dynamic: libzstd.so)"
      echo "  - libelf (static: libelf.a, dynamic: libelf.so)"
      echo "Use pkg-config-wrapper for package configuration"
      EOF
      chmod +x $out/bin/setup-env
    '';
    
    meta = {
      description = "Cross-compiled compression libraries (zlib, zstd) for ${system}";
    };
  };

in {
  inherit zlib-cross zstd-cross libelf-cross cross-libs;
  
  default = cross-libs;
} 
{ 
  dockerArch ? "amd64"
, sysArch ? "x86_64-linux"
, sysArchFull ? "x86_64-unknown-linux-gnu"
, crossArch ? "aarch64-unknown-linux-musl"

, sizeDisk ? 10240
, sizeBuildVMMem ? 5120

, nixpkgs ? import <nixpkgs>
, pkgs ? import <nixpkgs> { }
, pkgsLinux ? import <nixpkgs> { system = sysArch; }
}:

# TODO: Need to alias build tools on their native platforms.

rec {
  base = pkgs.dockerTools.buildImage {
    name = "to-build-" + dockerArch;
    tag = "base";
    created = "now";

    architecture = dockerArch;
    copyToRoot = pkgs.buildEnv {
      name = "image-root-base";
      paths = [
        pkgsLinux.bash
        pkgsLinux.cacert
        pkgsLinux.curl
        pkgsLinux.xz
        pkgsLinux.git
        pkgsLinux.perl
        pkgsLinux.lsb-release
      ];
      pathsToLink = [ "/bin" ];
    };

    config = {
      CMD = [ "/bin/bash" ];
      WorkingDir = "/project";
    };

    diskSize = sizeDisk;
    buildVMMemorySize = sizeBuildVMMem;
  };

  nativeTools = pkgs.dockerTools.buildImage {
    name = "to-build-" + dockerArch;
    tag = "nativeTools";
    created = "now";

    fromImage = base;

    architecture = dockerArch;
    copyToRoot = pkgs.buildEnv {
      name = "image-root-nativeTools";
      paths = [
        pkgsLinux.autoconf
        pkgsLinux.automake
        pkgsLinux.make
        pkgsLinux.libtool
        pkgsLinux.pkg-config
        pkgsLinux.cmake
        pkgsLinux.ninja
      ];
      pathsToLink = [ "/bin" ];
    };

    config = {
      CMD = [ "/bin/bash" ];
      WorkingDir = "/project";
    };

    diskSize = sizeDisk;
    buildVMMemorySize = sizeBuildVMMem;
  };

  cross = 
  let crossPkgs = (nixpkgs { crossSystem = { config = crossArch; }; }).pkgs;
  in pkgs.dockerTools.buildImage {
      name = "to-build-" + dockerArch;
      tag = "cross";
      created = "now";

      fromImage = nativeTools;

      architecture = dockerArch;
      copyToRoot = pkgs.buildEnv {
        name = "image-root-cross";
        paths = [
          crossPkgs.binutils
          crossPkgs.gcc12

          crossPkgs.musl
          crossPkgs.openssl_3_1
        ];
        pathsToLink = [ "/bin" ];
      };

      config = {
        CMD = [ "/bin/bash" ];
        WorkingDir = "/project";
      };

      diskSize = sizeDisk;
      buildVMMemorySize = sizeBuildVMMem;
    };
}

# TODO: Rust and cargo-prebuilt layer.

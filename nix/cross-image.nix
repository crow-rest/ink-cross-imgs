{ 
  dockerArch ? "amd64"
, sysArch ? "x86_64-unknown-linux-gnu"
, crossArch ? "aarch64-unknown-linux-gnu"

, nixpkgs ? import <nixpkgs>
, pkgs ? import <nixpkgs> { }
, pkgsLinux ? import <nixpkgs> { system = sysArch; }
}:

rec {
  base = pkgs.dockerTools.buildImage {
    name = "to-build" + dockerArch;
    tag = "base";
    created = "now";

    architecture = dockerArch;
    copyToRoot = pkgs.buildEnv {
      name = "image-root-base";
      paths = [
        pkgsLinux.bash
        pkgsLinux.curl
      ];
      pathsToLink = [ "/bin" ];
    };

    config = {
      CMD = [ "/bin/bash" ];
      WorkingDir = "/project";
    };

    diskSize = 10240;
    buildVMMemorySize = 5120;
  };

  nativeTools = pkgs.dockerTools.buildImage {
    name = "to-build" + dockerArch;
    tag = "nativeTools";
    created = "now";

    fromImage = base;

    architecture = dockerArch;
    copyToRoot = pkgs.buildEnv {
      name = "image-root-nativeTools";
      paths = [
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

    diskSize = 10240;
    buildVMMemorySize = 5120;
  };

  cross = 
  let crossPkgs = (nixpkgs { crossSystem = { config = crossArch; }; }).pkgs;
  in pkgs.dockerTools.buildImage {
      name = "to-build" + dockerArch;
      tag = "cross";
      created = "now";

      fromImage = nativeTools;

      architecture = dockerArch;
      copyToRoot = pkgs.buildEnv {
        name = "image-root-cross";
        paths = [
          crossPkgs.gcc12
        ];
        pathsToLink = [ "/bin" ];
      };

      config = {
        CMD = [ "/bin/bash" ];
        WorkingDir = "/project";
      };

      diskSize = 10240;
      buildVMMemorySize = 5120;
    };
}

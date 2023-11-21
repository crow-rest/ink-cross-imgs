{ pkgs ? import <nixpkgs> { }
, pkgsLinux ? import <nixpkgs> { system = "x86_64-linux"; }
, pkgsCross ? import <nixpkgs> { crossSystem = "aarch64-unknown-linux-gnu"; }
}:

rec {
  base = pkgs.dockerTools.buildImage {
    name = "to-build-x86_64";
    tag = "base";
    created = "now";

    architecture = "amd64";
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
    name = "to-build-x86_64";
    tag = "nativeTools";
    created = "now";

    fromImage = base;

    architecture = "amd64";
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

  cross = pkgs.dockerTools.buildImage {
      name = "to-build-x86_64";
      tag = "cross";
      created = "now";

      fromImage = nativeTools;

      architecture = "amd64";
      copyToRoot = pkgs.buildEnv {
        name = "image-root-cross";
        paths = [
          pkgsCross.gcc12
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

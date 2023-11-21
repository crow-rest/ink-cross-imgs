{ pkgs ? import <nixpkgs> { }
, pkgsLinux ? import <nixpkgs> { system = "x86_64-linux"; }
, pkgsCross ? import <nixpkgs>
}:

rec {
  base = pkgs.dockerTools.buildImage {
    name = "to-build";
    tag = "no-push";
    created = "now";

    architecture = "amd64";
    copyToRoot = pkgs.buildEnv {
      name = "image-root";
      paths = [
        pkgsLinux.bash
        pkgsLinux.curl

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
    let crossPkgs = pkgsCross.aarch64-multiplatform;
    in pkgs.dockerTools.buildImage {
      name = "to-build";
      tag = "no-push";
      created = "now";

      fromImage = base;

      architecture = "amd64";
      copyToRoot = pkgs.buildEnv {
        name = "image-root";
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

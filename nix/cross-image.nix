{ pkgs ? import <nixpkgs> { }
, pkgsLinux ? import <nixpkgs> { system = "x86_64-linux"; }
}:

pkgs.dockerTools.buildImage {
  name = "to-build";
  tag = "no-push";
  created = "now";

  architecture = "amd64";
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [
      pkgs.bash
      pkgs.curl

      pkgs.pkg-config
      pkgs.cmake
      pkgs.ninja
    ];
    pathsToLink = [ "/bin" ];
  };

  config = {
    CMD = [ "/bin/bash" ];
    WorkingDir = "/project";
  };

  diskSize = 10240;
  buildVMMemorySize = 5120;
}

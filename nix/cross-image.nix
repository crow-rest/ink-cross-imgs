{ pkgs ? import <nixpkgs> { }
, pkgsLinux ? import <nixpkgs> { system = "x86_64-linux"; }
}:

pkgs.dockerTools.buildImage {
  name = "to-build";
  tag = "no-push";
  created = "now";

  architecture = [ "aarch64" "x86_64" ];
  config = {
    CMD = [ "/bin/bash" ];
    WorkingDir = "/project";
  };

  diskSize = 10240;
  buildVMMemorySize = 5120;
}

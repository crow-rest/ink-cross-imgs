{ name ? "null", cmd ? ({ cargo }: "${cargo}/bin/cargo"), tagBase ? "latest" }:

let
  buildImage = arch:
    { dockerTools, callPackage }:
    dockerTools.buildImage {
      inherit name;
      tag = "${tagBase}-${arch}";
      config = { Cmd = [ (callPackage cmd { }) ]; };
    };
  architectures = [ "x86_64" "aarch64" ];
  nixpkgs = import <nixpkgs>;
  crossSystems = map (arch: {
    inherit arch;
    pkgs = (nixpkgs {
      crossSystem = { config = "${arch}-unknown-linux-musl"; };
    }).pkgsStatic;
  }) architectures;
  pkgs = nixpkgs { };
  lib = pkgs.lib;
  images = map ({ arch, pkgs }: rec {
    inherit arch;
    image = pkgs.callPackage (buildImage arch) { };
    tag = "${tagBase}-${arch}";
  }) crossSystems;
  loadAndPush = builtins.concatStringsSep "\n" (lib.concatMap
    ({ arch, image, tag }: [
      "$docker load -i ${image}"
      # "$docker push ${name}:${tag}"
    ]) images);
  imageNames = builtins.concatStringsSep " "
    (map ({ arch, image, tag }: "${name}:${tag}") images);

in pkgs.writeTextFile {
  inherit name;
  text = ''
    #!${pkgs.stdenv.shell}
    set -euxo pipefail
    docker=${pkgs.docker}/bin/docker
    ${loadAndPush}
    $docker manifest create --amend ${name}:${tagBase} ${imageNames}
    $docker manifest push ${name}:${tagBase}
  '';
  executable = true;
  destination = "/bin/push";
}

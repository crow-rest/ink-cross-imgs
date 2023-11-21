FROM nixos/nix:latest

RUN nix-channel --update

RUN --mount=type=bind,source=./crossShell.nix,target=/crossShell.nix nix-shell /crossShell.nix

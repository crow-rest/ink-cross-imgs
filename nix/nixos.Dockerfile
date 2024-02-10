FROM nixos/nix:latest

RUN nix-channel --update

RUN --mount=type=bind,source=./crossShell.nix,target=/crossShell.nix nix-shell /crossShell.nix

# TODO: prune all first
# TODO: Use nix-build then export TAR
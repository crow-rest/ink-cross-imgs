#!/bin/bash

set -euxo pipefail

mkdir -p /tmp/prebuilt
pushd /tmp/prebuilt

mkdir -p "$CARGO_HOME"/bin
case "$TARGETARCH" in
amd64)
    $EXT_CURL_CMD "https://github.com/cargo-prebuilt/cargo-prebuilt/releases/latest/download/x86_64-unknown-linux-musl.tar.gz" -o x86_64-unknown-linux-musl.tar.gz
    $EXT_CURL_CMD "https://github.com/cargo-prebuilt/cargo-prebuilt/releases/latest/download/hashes.sha256" | sha256sum -c --ignore-missing -
    tar -xzvf x86_64-unknown-linux-musl.tar.gz -C "$CARGO_HOME/bin"
    ;;
arm64)
    $EXT_CURL_CMD "https://github.com/cargo-prebuilt/cargo-prebuilt/releases/latest/download/aarch64-unknown-linux-musl.tar.gz" -o aarch64-unknown-linux-musl.tar.gz
    $EXT_CURL_CMD "https://github.com/cargo-prebuilt/cargo-prebuilt/releases/latest/download/hashes.sha256" | sha256sum -c --ignore-missing -
    tar -xzvf aarch64-unknown-linux-musl.tar.gz -C "$CARGO_HOME/bin"
    ;;
*)
    echo "Unsupported Arch: $TARGETARCH" && exit 1
    ;;
esac

# Packages
cargo-prebuilt cargo-zigbuild,cargo-auditable,cargo-quickinstall,cargo-binstall

# cargo zigbuild/auditable alias
echo '#!/bin/sh' > "$CARGO_HOME"/bin/cargo-za
echo "shift;" >> "$CARGO_HOME"/bin/cargo-za
echo "export CARGO=\"cargo-zigbuild\"" >> "$CARGO_HOME"/bin/cargo-za
echo "exec cargo-auditable auditable zigbuild --target $RUST_TARGET \"\$@\"" >> "$CARGO_HOME"/bin/cargo-za
chmod +x "$CARGO_HOME"/bin/cargo-za

popd
rm -rf /tmp/prebuilt

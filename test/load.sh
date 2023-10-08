#!/bin/bash

set -euxo pipefail

targets=(
    aarch64-unknown-linux-gnu
    aarch64-unknown-linux-musl
    armv7-unknown-linux-gnueabihf
    armv7-unknown-linux-musleabihf
    powerpc64le-unknown-linux-gnu
    riscv64gc-unknown-linux-gnu
    s390x-unknown-linux-gnu
    x86_64-unknown-linux-gnu
    x86_64-unknown-linux-musl
)

# Load images
for t in "${targets[@]}"
do
    docker load -i cross-$t-amd64.tar
done

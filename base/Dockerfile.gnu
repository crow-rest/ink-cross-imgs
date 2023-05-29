# syntax=docker/dockerfile:1
FROM debian:unstable-slim

# Do not set
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

ARG RUST_VERSION
ONBUILD ARG RUST_TARGET
ARG RUSTUP_VERSION=1.26.0

ARG CMAKE_VERSION=3.26.4

ONBUILD ARG GCC_PKGS
ONBUILD ARG CROSS_TOOLCHAIN
ONBUILD ARG CROSS_TOOLCHAIN_PREFIX

ONBUILD ARG OPENSSL_VERSION=3.0.8
ONBUILD ARG OPENSSL_COMBO

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

SHELL ["/bin/bash", "-c"]

# RUN <<EOT
#     apt update
#     apt upgrade -y
#     apt install -y --no-install-recommends \
#         ca-certificates \
#         curl \
#         make \
#         perl \
#         pkg-config \
#         git \
#         gcc
#     rm -rf /var/lib/apt/lists/*
# EOT

RUN <<EOT
    apt update
    apt upgrade -y
    apt install -y --no-install-recommends \
      autoconf \
      automake \
      binutils \
      ca-certificates \
      curl \
      file \
      gcc \
      git \
      libtool \
      m4 \
      make \
      g++ \
      libc6-dev \
      libclang-dev \
      pkg-config
    rm -rf /var/lib/apt/lists/*
EOT

# Install rust
RUN <<EOT
    case "$TARGETARCH" in
      amd64)
        export RUSTUP_ARCH="x86_64-unknown-linux-gnu"
        ;;
      arm64)
        export RUSTUP_ARCH="aarch64-unknown-linux-gnu"
        ;;
      *)
        echo "Unsupported Arch: $TARGETARCH" && exit 1
        ;;
    esac
    mkdir -p "target/$RUSTUP_ARCH/release"
    curl --retry 3 -fsSL "https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUSTUP_ARCH/rustup-init" -o "target/$RUSTUP_ARCH/release/rustup-init"
    curl --retry 3 -fsSL "https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUSTUP_ARCH/rustup-init.sha256" | sha256sum -c -
    chmod +x "target/$RUSTUP_ARCH/release/rustup-init"
    ./"target/$RUSTUP_ARCH/release/rustup-init" -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host $RUSTUP_ARCH
    rm -rf target
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME
EOT

# Install rust target
ONBUILD RUN <<EOT
    rustup target add "$RUST_TARGET"
EOT

# CMake
RUN <<EOT
    case "$TARGETARCH" in
      amd64)
        export CMAKE_ARCH="x86_64"
        ;;
      arm64)
        export CMAKE_ARCH="aarch64"
        ;;
      *)
        echo "Unsupported Arch: $TARGETARCH" && exit 1
        ;;
    esac
    curl --retry 3 -fsSL "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh" -O
    curl --retry 3 -fsSL "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-SHA-256.txt" | sha256sum -c -
    sh "cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh" --skip-license --prefix=/usr/local
    rm -f "cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh"
EOT

COPY toolchain.cmake /opt/toolchain.cmake

# Gcc pkgs
ONBUILD RUN <<EOT
    apt update
    apt install -y --no-install-recommends $GCC_PKGS
    rm -rf /var/lib/apt/lists/*
EOT

# CC
ONBUILD RUN <<EOT bash
    echo '#!/bin/sh' > "$CROSS_TOOLCHAIN_PREFIX"cc \
      && echo "$CROSS_TOOLCHAIN_PREFIX"gcc' "$@"' > /usr/bin/"$CROSS_TOOLCHAIN_PREFIX"cc \
      && chmod +x /usr/bin/"$CROSS_TOOLCHAIN_PREFIX"cc
EOT

# Openssl
ONBUILD RUN <<EOT
#   apt update
#   apt install -y --no-install-recommends \
#     ca-certificates \
#     curl \
#     pkg-config

    curl --retry 3 -fsSL "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz
    tar -xzf openssl.tar.gz
    rm -f openssl.tar.gz
    cd "/openssl-$OPENSSL_VERSION"

    AR="$CROSS_TOOLCHAIN_PREFIX"ar CC="$CROSS_TOOLCHAIN_PREFIX"gcc ./Configure $OPENSSL_COMBO \
      --libdir=lib --prefix="/usr/$CROSS_TOOLCHAIN/local" --openssldir="/usr/$CROSS_TOOLCHAIN/local/ssl" \
      no-dso no-shared no-ssl3 no-tests no-comp \
      no-legacy no-camellia no-idea no-seed
    make "-j$(nproc)"
    make "-j$(nproc)" install_sw
    make "-j$(nproc)" install_ssldirs

    cd /
    rm -rf "/openssl-$OPENSSL_VERSION"

#     rm -rf /var/lib/apt/lists/*
EOT

# Qemu
# RUN <<EOT
#     mkdir /qemu-tmp
#     cd /qemu-tmp
#     curl --retry 3 -fsSL "https://download.qemu.org/qemu-8.0.0.tar.xz" -O
#     tar --strip-components=1 -xJf "qemu-8.0.0.tar.xz"
#     ./configure \
#         --disable-kvm \
#         --disable-vnc \
#         --disable-guest-agent \
#         --enable-linux-user \
#         --static \
#         --target-list="aarch64-linux-user,aarch64-softmmu"
#     make "-j$(nproc)"
#     make install
#     ln -s "/usr/local/bin/qemu-aarch64" "/usr/bin/qemu-aarch64-static"
#     rm -rf /qemu-temp
# EOT

SHELL ["/bin/sh", "-c"]

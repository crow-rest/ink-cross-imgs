# syntax=docker/dockerfile:1
FROM debian:unstable-slim

#TODO: Do not hardcode versions
#TODO: Optimize args

# Do not set
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

# Shared
ARG RUST_VERSION=1.70.0
ONBUILD ARG RUST_TARGET
ARG RUSTUP_VERSION=1.26.0

ARG CMAKE_VERSION=3.26.4

ONBUILD ARG CROSS_TOOLCHAIN
ONBUILD ARG CROSS_TOOLCHAIN_PREFIX

ONBUILD ARG OPENSSL_VERSION=3.1.1
ONBUILD ARG OPENSSL_COMBO

# Not Shared
ONBUILD ARG GCC_PKGS

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

SHELL ["/bin/bash", "-c"]

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
ONBUILD ENV RUST_TARGET=$RUST_TARGET
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

# Openssl
ONBUILD ENV OPENSSL_INCLUDE_DIR=/usr/local/$CROSS_TOOLCHAIN/include
ONBUILD ENV OPENSSL_LIB_DIR=/usr/local/$CROSS_TOOLCHAIN/lib
ONBUILD RUN <<EOT
    curl --retry 3 -fsSL "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz
    tar -xzf openssl.tar.gz
    rm -f openssl.tar.gz
    cd "/openssl-$OPENSSL_VERSION"

    AR="$CROSS_TOOLCHAIN_PREFIX"ar CC="$CROSS_TOOLCHAIN_PREFIX"gcc ./Configure $OPENSSL_COMBO \
      --libdir=lib --prefix="/usr/local/$CROSS_TOOLCHAIN" --openssldir="/usr/local/$CROSS_TOOLCHAIN/ssl" \
      no-dso no-shared no-ssl3 no-tests no-comp \
      no-legacy no-camellia no-idea no-seed
    make "-j$(nproc)"
    make "-j$(nproc)" install_sw
    make "-j$(nproc)" install_ssldirs

    cd /
    rm -rf "/openssl-$OPENSSL_VERSION"
EOT

# Cargo prebuilt
RUN <<EOT
    case "$TARGETARCH" in
      amd64)
        curl --retry 3 -fsSL "https://github.com/cargo-prebuilt/cargo-prebuilt/releases/latest/download/x86_64-unknown-linux-gnu.tar.gz" -o x86_64-unknown-linux-gnu.tar.gz
        curl --retry 3 -fsSL "https://github.com/cargo-prebuilt/cargo-prebuilt/releases/latest/download/x86_64-unknown-linux-gnu.sha256" | sha256sum -c -
        tar -xzvf x86_64-unknown-linux-gnu.tar.gz -C "$CARGO_HOME/bin"
        rm -f x86_64-unknown-linux-gnu.tar.gz
        ;;
      arm64)
        curl --retry 3 -fsSL "https://github.com/cargo-prebuilt/cargo-prebuilt/releases/latest/download/aarch64-unknown-linux-gnu.tar.gz" -o aarch64-unknown-linux-gnu.tar.gz
        curl --retry 3 -fsSL "https://github.com/cargo-prebuilt/cargo-prebuilt/releases/latest/download/aarch64-unknown-linux-gnu.sha256" | sha256sum -c -
        tar -xzvf aarch64-unknown-linux-gnu.tar.gz -C "$CARGO_HOME/bin"
        rm -f aarch64-unknown-linux-gnu.tar.gz
        ;;
      *)
        echo "Unsupported Arch: $TARGETARCH" && exit 1
        ;;
    esac
EOT

# Cargo bins
RUN <<EOT
    cargo prebuilt cargo-auditable,cargo-quickinstall,cargo-binstall
EOT

SHELL ["/bin/sh", "-c"]

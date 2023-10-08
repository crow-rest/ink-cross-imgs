# syntax=docker/dockerfile:1
FROM debian:stable-slim

# Build CMDS
ARG EXT_CURL_CMD="curl --retry 3 -fsSL"

# Updatable
ARG RUSTUP_VERSION=1.26.0
ARG CMAKE_VERSION=3.27.7
ARG OPENSSL_VERSION=3.1.3

# Do not set
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

ARG RUST_VERSION=stable
ARG RUST_TARGET=s390x-unknown-linux-gnu

ARG CROSS_TOOLCHAIN=s390x-linux-gnu
ARG CROSS_TOOLCHAIN_PREFIX="$CROSS_TOOLCHAIN"-
ARG CROSS_SYSROOT=/usr/"$CROSS_TOOLCHAIN"

ARG OPENSSL_COMBO=linux64-s390x

ARG GCC_PKGS="g++-s390x-linux-gnu libc6-dev-s390x-cross"

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

SHELL ["/bin/bash", "-c"]

RUN <<EOT
    set -euxo pipefail
    apt update
    apt upgrade -y --no-install-recommends
    apt install -y --no-install-recommends \
        ca-certificates \
        curl \
        lsb-release \
        pkg-config \
        autoconf \
        automake \
        make \
        libtool \
        git \
        perl \
        xz-utils
    rm -rf /var/lib/apt/lists/*
EOT

# Install rust
RUN <<EOT
    set -euxo pipefail
    mkdir -p /tmp/rustup
    pushd /tmp/rustup

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
    $EXT_CURL_CMD "https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUSTUP_ARCH/rustup-init" -o "target/$RUSTUP_ARCH/release/rustup-init"
    $EXT_CURL_CMD "https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUSTUP_ARCH/rustup-init.sha256" | sha256sum -c -
    chmod +x "target/$RUSTUP_ARCH/release/rustup-init"
    ./"target/$RUSTUP_ARCH/release/rustup-init" -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host $RUSTUP_ARCH
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

    popd
    rm -rf /tmp/rustup
EOT

# Install rust target
ENV RUST_TARGET=$RUST_TARGET
RUN <<EOT
    set -euxo pipefail
    rustup target add "$RUST_TARGET"
EOT

# CMake
RUN <<EOT
    set -euxo pipefail
    mkdir -p /tmp/cmake
    pushd /tmp/cmake

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
    $EXT_CURL_CMD "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh" -O
    $EXT_CURL_CMD "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-SHA-256.txt" | sha256sum -c --ignore-missing -
    sh "cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh" --skip-license --prefix=/usr/local

    popd
    rm -rf /tmp/cmake
EOT

COPY toolchain-gcc.cmake /opt/toolchain.cmake

# Gcc pkgs
RUN <<EOT
    set -euxo pipefail
    apt update
    apt install -y --no-install-recommends $GCC_PKGS
    rm -rf /var/lib/apt/lists/*
EOT

# Openssl
ENV OPENSSL_INCLUDE_DIR=/usr/local/$CROSS_TOOLCHAIN/include
ENV OPENSSL_LIB_DIR=/usr/local/$CROSS_TOOLCHAIN/lib
RUN <<EOT
    set -euxo pipefail
    mkdir -p /tmp/openssl
    pushd /tmp/openssl

    $EXT_CURL_CMD "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz
    tar -xzf openssl.tar.gz
    rm -f openssl.tar.gz
    cd "./openssl-$OPENSSL_VERSION"

    AR="$CROSS_TOOLCHAIN_PREFIX"ar CC="$CROSS_TOOLCHAIN_PREFIX"gcc ./Configure $OPENSSL_COMBO \
      --libdir=lib --prefix="/usr/local/$CROSS_TOOLCHAIN" --openssldir="/usr/local/$CROSS_TOOLCHAIN/ssl" \
      no-dso no-shared no-ssl3 no-tests no-comp \
      no-legacy no-camellia no-idea no-seed
    make "-j$(nproc)"
    make "-j$(nproc)" install_sw
    make "-j$(nproc)" install_ssldirs

    popd
    rm -rf /tmp/openssl
EOT

# Cargo prebuilt
RUN <<EOT
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

    popd
    rm -rf /tmp/prebuilt
EOT

# Cargo bins
RUN <<EOT
    set -euxo pipefail
    cargo prebuilt cargo-auditable,cargo-quickinstall,cargo-binstall
EOT

ENV CROSS_TOOLCHAIN_PREFIX=$CROSS_TOOLCHAIN_PREFIX
ENV CROSS_SYSROOT=$CROSS_SYSROOT
ENV CARGO_TARGET_S390X_UNKNOWN_LINUX_GNU_LINKER="$CROSS_TOOLCHAIN_PREFIX"gcc \
    AR_s390x_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"ar \
    CC_s390x_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"gcc \
    CXX_s390x_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"g++ \
    CMAKE_TOOLCHAIN_FILE_s390x_unknown_linux_gnu=/opt/toolchain.cmake \
    BINDGEN_EXTRA_CLANG_ARGS_s390x_unknown_linux_gnu="--sysroot=$CROSS_SYSROOT" \
    RUST_TEST_THREADS=1 \
    PKG_CONFIG_ALLOW_CROSS_s390x_unknown_linux_gnu=true \
    PKG_CONFIG_PATH="/usr/local/$CROSS_TOOLCHAIN/lib/pkgconfig/:/usr/lib/$CROSS_TOOLCHAIN/pkgconfig/:${PKG_CONFIG_PATH}" \
    CROSS_CMAKE_SYSTEM_NAME=Linux \
    CROSS_CMAKE_SYSTEM_PROCESSOR=s390x \
    CROSS_CMAKE_CRT=gnu \
    CROSS_CMAKE_OBJECT_FLAGS="-ffunction-sections -fdata-sections -fPIC"

ENV CARGO_BUILD_TARGET=$RUST_TARGET\
    CARGO_TERM_COLOR=always

WORKDIR /project
ENTRYPOINT [ "cargo", "+stable" ]
CMD [ "auditable", "build" ]

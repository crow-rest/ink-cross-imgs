# syntax=docker/dockerfile:1
FROM debian:latest

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

ARG EXT_CURL_CMD="curl --retry 3 -fsSL"

ARG CROSS_TOOLCHAIN=x86_64-unknown-freebsd13
ARG CROSS_TOOLCHAIN_PREFIX="$CROSS_TOOLCHAIN"-
ARG CROSS_SYSROOT=/usr/"$CROSS_TOOLCHAIN"

ARG CMAKE_VERSION=3.26.4

ARG RUSTUP_VERSION=1.26.0
ARG RUST_VERSION=1.71.0

ARG LLVM_TARGET=x86_64-unknown-freebsd
ARG LLVM_VERSION=16

ARG OPENSSL_VERSION=3.0.9
ARG OPENSSL_COMBO=BSD-x86_64

SHELL ["/bin/bash", "-c"]

# Upgrade packages and install common ones.
RUN <<EOT
    set -euxo pipefail
    apt update
    apt upgrade -y
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

# CMake
RUN <<EOT
    set -euxo pipefail
    case "$TARGETARCH" in
      amd64)
        export CMAKE_ARCH="x86_64"
        ;;
      arm64)
        export CMAKE_ARCH="aarch64"
        ;;
      *)
        echo "Unsupported Arch (cmake): $TARGETARCH" && exit 1
        ;;
    esac
    $EXT_CURL_CMD "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh" -O
    $EXT_CURL_CMD "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-SHA-256.txt" | sha256sum -c --ignore-missing -
    sh "cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh" --skip-license --prefix=/usr/local
    rm -f "cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh"
EOT

COPY toolchain-clang.cmake /opt/toolchain.cmake

# Install rust
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
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

RUN rustup target add "$LLVM_TARGET"

# Install clang
# TODO: Why does the script need to be ran twice?
RUN <<EOT
    set -euxo pipefail
    apt update
    apt install -y wget software-properties-common gnupg
    
    $EXT_CURL_CMD https://apt.llvm.org/llvm.sh -o llvm.sh
    chmod +x llvm.sh
    ./llvm.sh "$LLVM_VERSION"
    ./llvm.sh "$LLVM_VERSION"
    rm -f llvm.sh
    
    apt purge -y wget software-properties-common gnupg
    apt autoremove -y
    rm -rf /var/lib/apt/lists/*
EOT

# Install freebsd base
RUN <<EOT
    set -euxo pipefail
    mkdir -p /tmp/freebsd
    pushd /tmp/freebsd

    $EXT_CURL_CMD http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/13.2-RELEASE/base.txz -o base.txz
    # $EXT_CURL_CMD http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/13.2-RELEASE/lib32.txz -o lib32.txz
    tar -xJvf base.txz
    # tar -xJvf lib32.txz

    mkdir -p "$CROSS_SYSROOT"
    cp -r lib "$CROSS_SYSROOT"/

    mkdir -p "$CROSS_SYSROOT"/usr
    cp -r usr/include "$CROSS_SYSROOT"/usr/
    cp -r usr/lib "$CROSS_SYSROOT"/usr/

    mkdir -p "$CROSS_SYSROOT"/usr/local
    cp -r usr/local/include "$CROSS_SYSROOT"/usr/local/
    cp -r usr/local/lib "$CROSS_SYSROOT"/usr/local/

    popd
    rm -rf /tmp/freebsd
EOT

# Set Alts for clang
RUN <<EOT
    set -euxo pipefail
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/cc cc /usr/bin/clang-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-"$LLVM_VERSION" 100
    clang --version
    cc --version
    clang++ --version
    c++ --version
    
    update-alternatives --install /usr/bin/lld lld /usr/bin/lld-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/ld ld /usr/bin/lld-"$LLVM_VERSION" 100
    lld --version
    ld --version
    
    update-alternatives --install /usr/bin/ar ar /usr/bin/llvm-ar-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/as as /usr/bin/llvm-as-"$LLVM_VERSION" 100
    ar --version
    as --version
    
    update-alternatives --install /usr/bin/nm nm /usr/bin/llvm-nm-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/objcopy objcopy /usr/bin/llvm-objcopy-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/objdump objdump /usr/bin/llvm-objdump-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/ranlib ranlib /usr/bin/llvm-ranlib-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/strip strip /usr/bin/llvm-strip-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/strings strings /usr/bin/llvm-strings-"$LLVM_VERSION" 100
    nm --version
    objcopy --version
    objdump --version
    ranlib --version
    strip --version
    strings --version
EOT

# Setup clang cross compile
# TODO: More stuff from above!!!
ENV PATH=$PATH:$CROSS_SYSROOT/bin
ENV CC="$CROSS_TOOLCHAIN_PREFIX"clang
ENV CXX="$CROSS_TOOLCHAIN_PREFIX"clang++
ENV AR="$CROSS_TOOLCHAIN_PREFIX"ar 
RUN <<EOT
    set -euxo pipefail
    mkdir -p "$CROSS_SYSROOT"/bin
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang
    echo "exec /usr/bin/clang --target=$LLVM_TARGET --sysroot=$CROSS_SYSROOT \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang++
    echo "exec /usr/bin/clang++ --target=$LLVM_TARGET --sysroot=$CROSS_SYSROOT -stdlib=libc++ \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang++
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang++
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar
    echo "exec /usr/bin/ar \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld
    echo "exec /usr/bin/ld \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm
    echo "exec /usr/bin/nm \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy
    echo "exec /usr/bin/objcopy \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump
    echo "exec /usr/bin/objdump \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib
    echo "exec /usr/bin/ranlib \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip
    echo "exec /usr/bin/strip \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip
    
    "$CROSS_TOOLCHAIN_PREFIX"clang --version
    "$CROSS_TOOLCHAIN_PREFIX"clang++ --version
    "$CROSS_TOOLCHAIN_PREFIX"ar --version
    "$CROSS_TOOLCHAIN_PREFIX"ld --version
    "$CROSS_TOOLCHAIN_PREFIX"nm --version
    "$CROSS_TOOLCHAIN_PREFIX"objcopy --version
    "$CROSS_TOOLCHAIN_PREFIX"objdump --version
    "$CROSS_TOOLCHAIN_PREFIX"ranlib --version
    "$CROSS_TOOLCHAIN_PREFIX"strip --version
EOT

# OpenSSL
ENV OPENSSL_INCLUDE_DIR=/usr/local/$CROSS_TOOLCHAIN/include
ENV OPENSSL_LIB_DIR=/usr/local/$CROSS_TOOLCHAIN/lib
RUN <<EOT
    set -euxo pipefail
    mkdir -p /tmp/openssl
    pushd /tmp/openssl

    $EXT_CURL_CMD "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz
    tar -xzvf openssl.tar.gz
    rm -f openssl.tar.gz
    pushd "./openssl-$OPENSSL_VERSION"

    AR="$CROSS_TOOLCHAIN_PREFIX"ar CC="$CROSS_TOOLCHAIN_PREFIX"clang ./Configure $OPENSSL_COMBO \
        --libdir=lib --prefix="/usr/local/$CROSS_TOOLCHAIN" --openssldir="/usr/local/$CROSS_TOOLCHAIN/ssl" \
        no-dso no-shared no-ssl3 no-tests no-comp \
        no-legacy no-camellia no-idea no-seed
    make "-j$(nproc)"
    make "-j$(nproc)" install_sw
    make "-j$(nproc)" install_ssldirs

    popd
    popd
    rm -rf /tmp/openssl
EOT

SHELL ["/bin/sh", "-c"]

# Cross env vars
ENV CROSS_TOOLCHAIN_PREFIX=$CROSS_TOOLCHAIN_PREFIX
ENV CROSS_SYSROOT=$CROSS_SYSROOT
ENV CARGO_TARGET_X86_64_UNKNOWN_FREEBSD_LINKER="$CROSS_TOOLCHAIN_PREFIX"clang \
    AR_x86_64_unknown_freebsd="$CROSS_TOOLCHAIN_PREFIX"ar \
    CC_x86_64_unknown_freebsd="$CROSS_TOOLCHAIN_PREFIX"clang \
    CXX_x86_64_unknown_freebsd="$CROSS_TOOLCHAIN_PREFIX"clang++ \
    CMAKE_TOOLCHAIN_FILE_x86_64_unknown_freebsd=/opt/toolchain.cmake \
    BINDGEN_EXTRA_CLANG_ARGS_x86_64_unknown_freebsd="--sysroot=$CROSS_SYSROOT" \
    RUST_TEST_THREADS=1 \
    PKG_CONFIG_ALLOW_CROSS_x86_64_unknown_freebsd=true \
    PKG_CONFIG_PATH="/usr/local/$CROSS_TOOLCHAIN/lib/pkgconfig/:/usr/lib/$CROSS_TOOLCHAIN/pkgconfig/:${PKG_CONFIG_PATH}" \
    CROSS_CMAKE_SYSTEM_NAME=Linux \
    CROSS_CMAKE_SYSTEM_PROCESSOR=x86_64 \
    CROSS_CMAKE_CRT=gnu \
    CROSS_CMAKE_OBJECT_FLAGS="-ffunction-sections -fdata-sections -fPIC -m64" \
    CARGO_BUILD_TARGET=$LLVM_TARGET

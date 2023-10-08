# syntax=docker/dockerfile:1
FROM debian:latest

# Build CMDS
ARG EXT_CURL_CMD="curl --retry 3 -fsSL"

# Do not set
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

ARG RUST_VERSION=1.73.0
ARG RUST_TARGET=x86_64-unknown-linux-musl
ARG RUSTUP_VERSION=1.26.0

ARG CMAKE_VERSION=3.27.7

ARG CROSS_TOOLCHAIN=x86_64-linux-musl
ARG CROSS_TOOLCHAIN_PREFIX="$CROSS_TOOLCHAIN"-
ARG CROSS_SYSROOT=/usr/"$CROSS_TOOLCHAIN"

ARG OPENSSL_VERSION=3.1.3
ARG OPENSSL_COMBO=linux-x86_64

ARG GCC_PKGS="libgcc-12-dev-amd64-cross"

ARG LLVM_TARGET=$RUST_TARGET
ARG LLVM_VERSION=17

ARG MUSL_VERSION=1.2.4

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

SHELL ["/bin/bash", "-c"]

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

COPY toolchain-clang.cmake /opt/toolchain.cmake

# Gcc pkgs
RUN <<EOT
    set -euxo pipefail
    apt update
    apt install -y --no-install-recommends $GCC_PKGS
    rm -rf /var/lib/apt/lists/*
EOT

# Install clang
RUN <<EOT
    apt update
    apt install -y wget software-properties-common gnupg
    
    mkdir -p /tmp/llvm
    pushd /tmp/llvm

    $EXT_CURL_CMD https://apt.llvm.org/llvm.sh -o llvm.sh
    chmod +x llvm.sh
    ./llvm.sh "$LLVM_VERSION"

    set -euxo pipefail
    ./llvm.sh "$LLVM_VERSION"

    popd
    rm -rf /tmp/llvm

    apt purge -y wget software-properties-common gnupg
    apt autoremove -y
    rm -rf /var/lib/apt/lists/*
EOT

# Set Alts for clang
RUN <<EOT
    set -euxo pipefail
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/cc cc /usr/bin/clang-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-"$LLVM_VERSION" 100
    
    update-alternatives --install /usr/bin/lld lld /usr/bin/lld-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/ld ld /usr/bin/lld-"$LLVM_VERSION" 100
    
    update-alternatives --install /usr/bin/ar ar /usr/bin/llvm-ar-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/as as /usr/bin/llvm-as-"$LLVM_VERSION" 100
    
    update-alternatives --install /usr/bin/nm nm /usr/bin/llvm-nm-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/objcopy objcopy /usr/bin/llvm-objcopy-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/objdump objdump /usr/bin/llvm-objdump-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/ranlib ranlib /usr/bin/llvm-ranlib-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/strip strip /usr/bin/llvm-strip-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/strings strings /usr/bin/llvm-strings-"$LLVM_VERSION" 100
EOT

# Setup clang cross compile
ENV PATH=$PATH:$CROSS_SYSROOT/bin
RUN <<EOT
    set -euxo pipefail
    mkdir -p "$CROSS_SYSROOT"/bin
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang
    echo "exec /usr/bin/clang-$LLVM_VERSION --target=$LLVM_TARGET --sysroot=$CROSS_SYSROOT -I=$CROSS_SYSROOT/include -L=$CROSS_SYSROOT/lib \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang++
    echo "exec /usr/bin/clang++-$LLVM_VERSION --target=$LLVM_TARGET --sysroot=$CROSS_SYSROOT -stdlib=libc++ \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang++
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang++
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar
    echo "exec /usr/bin/llvm-ar-$LLVM_VERSION \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as
    echo "exec /usr/bin/llvm-as-$LLVM_VERSION \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld
    echo "exec /usr/bin/lld-$LLVM_VERSION \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm
    echo "exec /usr/bin/llvm-nm-$LLVM_VERSION \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy
    echo "exec /usr/bin/llvm-objcopy-$LLVM_VERSION \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump
    echo "exec /usr/bin/llvm-objdump-$LLVM_VERSION \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib
    echo "exec /usr/bin/llvm-ranlib-$LLVM_VERSION \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib

    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip
    echo "exec /usr/bin/llvm-strip-$LLVM_VERSION \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip
    
    "$CROSS_TOOLCHAIN_PREFIX"clang --version
    "$CROSS_TOOLCHAIN_PREFIX"clang++ --version
    "$CROSS_TOOLCHAIN_PREFIX"ar --version
    "$CROSS_TOOLCHAIN_PREFIX"ld --version || true
    "$CROSS_TOOLCHAIN_PREFIX"nm --version
    "$CROSS_TOOLCHAIN_PREFIX"objcopy --version
    "$CROSS_TOOLCHAIN_PREFIX"objdump --version
    "$CROSS_TOOLCHAIN_PREFIX"ranlib --version
    "$CROSS_TOOLCHAIN_PREFIX"strip --version
EOT

# Install musl
RUN <<EOT
    set -euxo pipefail

    mkdir -p /tmp/musl
    pushd /tmp/musl

    $EXT_CURL_CMD https://musl.libc.org/releases/musl-"$MUSL_VERSION".tar.gz -o musl.tar.gz
    tar -xzvf musl.tar.gz
    cd musl-"$MUSL_VERSION"
    
    CROSS_COMPILE="$CROSS_TOOLCHAIN_PREFIX" CC="$CROSS_TOOLCHAIN_PREFIX"clang AR="$CROSS_TOOLCHAIN_PREFIX"ar \
        ./configure --prefix="$CROSS_SYSROOT" --disable-shared
    make "-j$(nproc)"
    make "-j$(nproc)" install
    
    popd
    rm -rf /tmp/musl
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

    AR="$CROSS_TOOLCHAIN_PREFIX"ar CC="$CROSS_TOOLCHAIN_PREFIX"clang" -fuse-ld=lld" ./Configure $OPENSSL_COMBO \
      --libdir=lib --prefix="/usr/local/$CROSS_TOOLCHAIN" --openssldir="/usr/local/$CROSS_TOOLCHAIN/ssl" \
      no-dso no-shared no-ssl3 no-tests no-comp \
      no-legacy no-camellia no-idea no-seed \
      no-engine no-async -DOPENSSL_NO_SECURE_MEMORY  # Musl options
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
ENV CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="$CROSS_TOOLCHAIN_PREFIX"clang \
    AR_x86_64_unknown_linux_musl="$CROSS_TOOLCHAIN_PREFIX"ar \
    CC_x86_64_unknown_linux_musl="$CROSS_TOOLCHAIN_PREFIX"clang \
    CXX_x86_64_unknown_linux_musl="$CROSS_TOOLCHAIN_PREFIX"clang++ \
    CMAKE_TOOLCHAIN_FILE_x86_64_unknown_linux_musl=/opt/toolchain.cmake \
    BINDGEN_EXTRA_CLANG_ARGS_x86_64_unknown_linux_musl="--sysroot=$CROSS_SYSROOT" \
    RUST_TEST_THREADS=1 \
    PKG_CONFIG_ALLOW_CROSS_x86_64_unknown_linux_musl=true \
    PKG_CONFIG_PATH="/usr/local/$CROSS_TOOLCHAIN/lib/pkgconfig/:/usr/lib/$CROSS_TOOLCHAIN/pkgconfig/:${PKG_CONFIG_PATH}" \
    CROSS_CMAKE_SYSTEM_NAME=Linux \
    CROSS_CMAKE_SYSTEM_PROCESSOR=x86_64 \
    CROSS_CMAKE_CRT=musl \
    CROSS_CMAKE_OBJECT_FLAGS="-ffunction-sections -fdata-sections -fPIC -m64"

ENV CARGO_BUILD_TARGET=$RUST_TARGET\
    CARGO_TERM_COLOR=always

WORKDIR /project
ENTRYPOINT [ "cargo" ]
CMD [ "auditable", "build" ]

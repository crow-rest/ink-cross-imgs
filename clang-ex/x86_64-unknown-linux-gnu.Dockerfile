# syntax=docker/dockerfile:1
FROM debian:latest

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

ARG CROSS_TOOLCHAIN=x86_64-linux-gnu
ARG CROSS_TOOLCHAIN_PREFIX="$CROSS_TOOLCHAIN"-
ARG CROSS_SYSROOT=/usr/"$CROSS_TOOLCHAIN"

ARG CMAKE_VERSION=3.26.4

ARG RUSTUP_VERSION=1.26.0
ARG RUST_VERSION=1.70.0

ARG LLVM_TARGET=x86_64-unknown-linux-gnu
ARG LLVM_VERSION=16

SHELL ["/bin/bash", "-c"]

# Upgrade packages and install common ones.
RUN <<EOT
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
        perl
    rm -rf /var/lib/apt/lists/*
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
        echo "Unsupported Arch (cmake): $TARGETARCH" && exit 1
        ;;
    esac
    curl --retry 3 -fsSL "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh" -O
    curl --retry 3 -fsSL "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-SHA-256.txt" | sha256sum -c -
    sh "cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh" --skip-license --prefix=/usr/local
    rm -f "cmake-$CMAKE_VERSION-linux-$CMAKE_ARCH.sh"
EOT

COPY toolchain.cmake /opt/toolchain.cmake

# Install rust
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

RUN <<EOT
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
    curl --retry 3 -fsSL "https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUSTUP_ARCH/rustup-init" -o "target/$RUSTUP_ARCH/release/rustup-init"
    curl --retry 3 -fsSL "https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$RUSTUP_ARCH/rustup-init.sha256" | sha256sum -c -
    chmod +x "target/$RUSTUP_ARCH/release/rustup-init"
    ./"target/$RUSTUP_ARCH/release/rustup-init" -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host $RUSTUP_ARCH
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME
    
    popd
    rm -rf /tmp/rustup
EOT

RUN rustup target add "$LLVM_TARGET"

# Install glibc
# TODO: Build from source?
RUN <<EOT
    apt update
    apt install -y --no-install-recommends \
        g++-x86-64-linux-gnu libc6-dev-amd64-cross
    rm -rf /var/lib/apt/lists/*
EOT

# Install clang
# TODO: Why does the script need to be ran twice?
RUN <<EOT
    apt update
    apt install -y wget software-properties-common gnupg
    
    wget https://apt.llvm.org/llvm.sh
    chmod +x llvm.sh
    ./llvm.sh "$LLVM_VERSION"
    ./llvm.sh "$LLVM_VERSION"
    rm -f llvm.sh
    
    apt purge -y wget software-properties-common gnupg
    apt autoremove -y
    rm -rf /var/lib/apt/lists/*
EOT

# Set Alts for clang
RUN <<EOT
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
    
    update-alternatives --install /usr/bin/objcopy objcopy /usr/bin/llvm-objcopy-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/objdump objdump /usr/bin/llvm-objdump-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/ranlib ranlib /usr/bin/llvm-ranlib-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/strings strings /usr/bin/llvm-strings-"$LLVM_VERSION" 100
    update-alternatives --install /usr/bin/strip strip /usr/bin/llvm-strip-"$LLVM_VERSION" 100
    objcopy --version
    objdump --version
    ranlib --version
    strings --version
    strip --version
EOT

# Setup clang cross compile
env PATH=$PATH:$CROSS_SYSROOT/bin
RUN <<EOT
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
    
    echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as
    echo "exec /usr/bin/as \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as
    chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as
    
    "$CROSS_TOOLCHAIN_PREFIX"clang --version
    "$CROSS_TOOLCHAIN_PREFIX"clang++ --version
    "$CROSS_TOOLCHAIN_PREFIX"ar --version
    "$CROSS_TOOLCHAIN_PREFIX"as --version
EOT

# TODO: OpenSSL

SHELL ["/bin/sh", "-c"]

# Cross env vars
ENV CROSS_TOOLCHAIN_PREFIX=$CROSS_TOOLCHAIN_PREFIX
ENV CROSS_SYSROOT=$CROSS_SYSROOT
ENV CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$CROSS_TOOLCHAIN_PREFIX"gcc \
    AR_x86_64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"ar \
    CC_x86_64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"clang \
    CXX_x86_64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"clang++ \
    CMAKE_TOOLCHAIN_FILE_x86_64_unknown_linux_gnu=/opt/toolchain.cmake \
    BINDGEN_EXTRA_CLANG_ARGS_x86_64_unknown_linux_gnu="--sysroot=$CROSS_SYSROOT" \
    RUST_TEST_THREADS=1 \
    PKG_CONFIG_ALLOW_CROSS_x86_64_unknown_linux_gnu=true \
    PKG_CONFIG_PATH="/usr/local/x86_64-linux-gnu/lib/pkgconfig/:/usr/lib/x86_64-linux-gnu/pkgconfig/:${PKG_CONFIG_PATH}" \
    CROSS_CMAKE_SYSTEM_NAME=Linux \
    CROSS_CMAKE_SYSTEM_PROCESSOR=x86_64 \
    CROSS_CMAKE_CRT=gnu \
    CROSS_CMAKE_OBJECT_FLAGS="-ffunction-sections -fdata-sections -fPIC -m64" \
    CARGO_BUILD_TARGET=$LLVM_TARGET

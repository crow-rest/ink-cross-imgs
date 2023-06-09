# syntax=docker/dockerfile:1
ARG RUST_TARGET=x86_64-unknown-linux-gnu
ARG GCC_PKGS="g++-x86-64-linux-gnu libc6-dev-amd64-cross"
ARG CROSS_TOOLCHAIN=x86_64-linux-gnu
ARG CROSS_TOOLCHAIN_PREFIX=x86_64-linux-gnu-
ARG OPENSSL_COMBO=linux-x86_64
FROM base-img-gnu:latest

ENV CROSS_TOOLCHAIN_PREFIX=x86_64-linux-gnu-
ENV CROSS_SYSROOT=/usr/x86_64-linux-gnu
ENV CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$CROSS_TOOLCHAIN_PREFIX"gcc \
    AR_x86_64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"ar \
    CC_x86_64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"gcc \
    CXX_x86_64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"g++ \
    CMAKE_TOOLCHAIN_FILE_x86_64_unknown_linux_gnu=/opt/toolchain.cmake \
    BINDGEN_EXTRA_CLANG_ARGS_x86_64_unknown_linux_gnu="--sysroot=$CROSS_SYSROOT" \
    RUST_TEST_THREADS=1 \
    PKG_CONFIG_ALLOW_CROSS_x86_64_unknown_linux_gnu=true \
    PKG_CONFIG_PATH="/usr/local/x86_64-linux-gnu/lib/pkgconfig/:/usr/lib/x86_64-linux-gnu/pkgconfig/:${PKG_CONFIG_PATH}" \
    CROSS_CMAKE_SYSTEM_NAME=Linux \
    CROSS_CMAKE_SYSTEM_PROCESSOR=x86_64 \
    CROSS_CMAKE_CRT=gnu \
    CROSS_CMAKE_OBJECT_FLAGS="-ffunction-sections -fdata-sections -fPIC -m64"

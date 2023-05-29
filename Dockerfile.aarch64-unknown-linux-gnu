# syntax=docker/dockerfile:1
ARG RUST_TARGET=aarch64-unknown-linux-gnu
FROM base-img-gnu

SHELL ["/bin/bash", "-c"]

SHELL ["/bin/sh", "-c"]

ENV CROSS_TOOLCHAIN_PREFIX=aarch64-linux-gnu-
ENV CROSS_SYSROOT=/usr/aarch64-linux-gnu
ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="$CROSS_TOOLCHAIN_PREFIX"gcc \
    AR_aarch64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"ar \
    CC_aarch64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"gcc \
    CXX_aarch64_unknown_linux_gnu="$CROSS_TOOLCHAIN_PREFIX"g++ \
    CMAKE_TOOLCHAIN_FILE_aarch64_unknown_linux_gnu=/opt/toolchain.cmake \
    BINDGEN_EXTRA_CLANG_ARGS_aarch64_unknown_linux_gnu="--sysroot=$CROSS_SYSROOT" \
    RUST_TEST_THREADS=1 \
    PKG_CONFIG_PATH="/usr/lib/aarch64-linux-gnu/pkgconfig/:${PKG_CONFIG_PATH}" \
    CROSS_CMAKE_SYSTEM_NAME=Linux \
    CROSS_CMAKE_SYSTEM_PROCESSOR=aarch64 \
    CROSS_CMAKE_CRT=gnu \
    CROSS_CMAKE_OBJECT_FLAGS="-ffunction-sections -fdata-sections -fPIC"

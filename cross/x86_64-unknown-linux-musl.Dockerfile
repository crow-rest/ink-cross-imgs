# syntax=docker/dockerfile:1
ARG RUST_TARGET=x86_64-unknown-linux-musl
ARG CROSS_TOOLCHAIN=x86_64-linux-musl
ARG CROSS_TOOLCHAIN_PREFIX=x86_64-linux-musl-
ARG OPENSSL_COMBO=linux-x86_64
FROM base-img-musl

ENV CROSS_TOOLCHAIN_PREFIX=x86_64-linux-musl-
ENV CROSS_SYSROOT=/usr/x86_64-linux-musl
ENV CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="$CROSS_TOOLCHAIN_PREFIX"gcc \
    AR_x86_64_unknown_linux_musl="$CROSS_TOOLCHAIN_PREFIX"ar \
    CC_x86_64_unknown_linux_musl="$CROSS_TOOLCHAIN_PREFIX"gcc \
    CXX_x86_64_unknown_linux_musl="$CROSS_TOOLCHAIN_PREFIX"g++ \
    CMAKE_TOOLCHAIN_FILE_x86_64_unknown_linux_musl=/opt/toolchain.cmake \
    BINDGEN_EXTRA_CLANG_ARGS_x86_64_unknown_linux_musl="--sysroot=$CROSS_SYSROOT" \
    RUST_TEST_THREADS=1 \
    PKG_CONFIG_ALLOW_CROSS_x86_64_unknown_linux_musl=true \
    PKG_CONFIG_PATH="/usr/local/x86_64-linux-musl/lib/pkgconfig/:/usr/lib/x86_64-linux-musl/pkgconfig/:${PKG_CONFIG_PATH}" \
    CROSS_CMAKE_SYSTEM_NAME=Linux \
    CROSS_CMAKE_SYSTEM_PROCESSOR=x86_64 \
    CROSS_CMAKE_CRT=musl \
    CROSS_CMAKE_OBJECT_FLAGS="-ffunction-sections -fdata-sections -fPIC -m64"

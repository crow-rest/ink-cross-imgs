#!/bin/bash

set -euxo pipefail

case "$TARGETARCH" in
amd64)
    export ZIG_ARCH="linux-x86_64"
    ;;
arm64)
    export ZIG_ARCH="linux-aarch64"
    ;;
*)
    echo "Unsupported Arch: $TARGETARCH" && exit 1
    ;;
esac

mkdir -p /tmp/zig
pushd /tmp/zig

# Install zig
$EXT_CURL_CMD "https://ziglang.org/download/$ZIG_VERSION/zig-$ZIG_ARCH-$ZIG_VERSION.tar.xz" -o zig.tar.xz
# $EXT_CURL_CMD "https://ziglang.org/builds/zig-$ZIG_ARCH-$ZIG_VERSION.tar.xz" -o zig.tar.xz
tar -xJvf zig.tar.xz

chmod +x zig-$ZIG_ARCH-$ZIG_VERSION/zig
cp zig-$ZIG_ARCH-$ZIG_VERSION/zig /usr/bin

mkdir -p /usr/lib/zig
cp -r zig-$ZIG_ARCH-$ZIG_VERSION/lib/* /usr/lib/zig/

popd
rm -rf /tmp/zig

zig version

# # Set clang alts
# update-alternatives --install /usr/bin/clang clang /usr/bin/clang-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/cc cc /usr/bin/clang-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-"$LLVM_VERSION" 100

# update-alternatives --install /usr/bin/lld lld /usr/bin/lld-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/ld ld /usr/bin/lld-"$LLVM_VERSION" 100

# update-alternatives --install /usr/bin/ar ar /usr/bin/llvm-ar-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/as as /usr/bin/llvm-as-"$LLVM_VERSION" 100

# update-alternatives --install /usr/bin/nm nm /usr/bin/llvm-nm-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/objcopy objcopy /usr/bin/llvm-objcopy-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/objdump objdump /usr/bin/llvm-objdump-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/ranlib ranlib /usr/bin/llvm-ranlib-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/strip strip /usr/bin/llvm-strip-"$LLVM_VERSION" 100
# update-alternatives --install /usr/bin/strings strings /usr/bin/llvm-strings-"$LLVM_VERSION" 100

# Setup zig cross compile
mkdir -p "$CROSS_SYSROOT"/bin

echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"zig
echo "exec /usr/bin/zig cc --target=$LLVM_TARGET -isysroot=$CROSS_SYSROOT \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang
chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"zig

echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"zig++
echo "exec /usr/bin/zig c++ --target=$LLVM_TARGET -isysroot=$CROSS_SYSROOT \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"clang++
chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"zig++

# echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar
# echo "exec /usr/bin/zig ar \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar
# chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ar

# echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as
# echo "exec /usr/bin/zig cc \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as
# chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"as

# echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld
# echo "exec /usr/bin/zig cc \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld
# chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ld

# echo '#!/bin/sh' >"$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm
# echo "exec /usr/bin/llvm-nm-$LLVM_VERSION \"\$@\"" >>"$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm
# chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"nm

# echo '#!/bin/sh' >"$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy
# echo "exec /usr/bin/llvm-objcopy-$LLVM_VERSION \"\$@\"" >>"$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy
# chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objcopy

# echo '#!/bin/sh' >"$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump
# echo "exec /usr/bin/llvm-objdump-$LLVM_VERSION \"\$@\"" >>"$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump
# chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"objdump

# echo '#!/bin/sh' > "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib
# echo "exec /usr/bin/zig ranlib \"\$@\"" >> "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib
# chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"ranlib

# echo '#!/bin/sh' >"$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip
# echo "exec /usr/bin/llvm-strip-$LLVM_VERSION \"\$@\"" >>"$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip
# chmod +x "$CROSS_SYSROOT"/bin/"$CROSS_TOOLCHAIN_PREFIX"strip

"$CROSS_TOOLCHAIN_PREFIX"zig --version
"$CROSS_TOOLCHAIN_PREFIX"zig++ --version
# "$CROSS_TOOLCHAIN_PREFIX"ar --version
# "$CROSS_TOOLCHAIN_PREFIX"as --version
# "$CROSS_TOOLCHAIN_PREFIX"ld --version
# "$CROSS_TOOLCHAIN_PREFIX"nm --version
# "$CROSS_TOOLCHAIN_PREFIX"objcopy --version
# "$CROSS_TOOLCHAIN_PREFIX"objdump --version
# "$CROSS_TOOLCHAIN_PREFIX"ranlib --version
# "$CROSS_TOOLCHAIN_PREFIX"strip --version

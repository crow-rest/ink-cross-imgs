# syntax=docker/dockerfile:1
FROM ubuntu:latest
ARG DEBIAN_FRONTEND=noninteractive

# Ports
RUN <<EOT bash
    sed 's/http:\/\/\(.*\).ubuntu.com\/ubuntu\//[arch-=amd64,i386] http:\/\/ports.ubuntu.com\/ubuntu-ports\//g' /etc/apt/sources.list > /etc/apt/sources.list.d/ports.list
    sed -i 's/http:\/\/\(.*\).ubuntu.com\/ubuntu\//[arch=amd64,i386] http:\/\/\1.archive.ubuntu.com\/ubuntu\//g' /etc/apt/sources.list
EOT

# Get packages
RUN <<EOT bash
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
        pkg-config \
        bison \
        bzip2 \
        flex \
        patch \
        python3 \
        xz-utils \
        libattr1-dev \
        libcap-ng-dev \
        libffi-dev \
        libglib2.0-dev \
        libpixman-1-dev \
        libselinux1-dev \
        zlib1g-dev \
        ninja-build
    rm -rf /var/lib/apt/lists/*
    apt purge --assume-yes --auto-remove curl
EOT

# CMake
RUN <<EOT bash
    curl --retry 3 -fsSL "https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4-linux-aarch64.sh" -o cmake.sh
    sh cmake.sh --skip-license --prefix=/usr/local
    rm -f cmake.sh
EOT

# Qemu
# RUN <<EOT bash
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

# syntax=docker/dockerfile:1.3-labs

ARG MODE=base
ARG ALPINE_VERSION=3.15

# https://pkgs.alpinelinux.org/package/edge/main/x86_64/clang
ARG LLVM_VERSION=12

FROM alpine:"${ALPINE_VERSION}" as slim
SHELL ["/bin/sh", "-eux", "-c"]
# - As of alpine 3.15, the ninja package is an alias for samurai.
# - Download-related packages (bzip2, curl, dpkg, libarchive-tools, tar, unzip, xz)
#   are not necessarily needed for build, but they are small enough (about 4MB).
RUN <<EOF
cat >>/etc/apk/repositories <<EOF2
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF2
apk --no-cache update -q
apk --no-cache upgrade
apk --no-cache add \
    autoconf \
    automake \
    bash \
    binutils \
    bzip2 \
    ca-certificates \
    cmake \
    curl \
    dpkg \
    file \
    g++ \
    git \
    libarchive-tools \
    libtool \
    make \
    patch \
    pkgconf \
    samurai \
    tar \
    unzip \
    xz
EOF

FROM slim as base
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG LLVM_VERSION
RUN <<EOF
apk --no-cache update -q
apk --no-cache add \
    clang \
    lld \
    llvm"${LLVM_VERSION}"
gcc --version
clang --version
cmake --version
EOF

FROM "${MODE:-base}" as final
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

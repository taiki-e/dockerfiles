# syntax=docker/dockerfile:1.3-labs

ARG ALPINE_VERSION=3.15

# https://pkgs.alpinelinux.org/package/edge/main/x86_64/cmake
ARG CMAKE_VERSION=3.21
# https://pkgs.alpinelinux.org/package/edge/main/x86_64/clang
ARG LLVM_VERSION=12

FROM alpine:"${ALPINE_VERSION}"
SHELL ["/bin/sh", "-eux", "-c"]
ARG LLVM_VERSION
ARG CMAKE_VERSION
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
    ca-certificates \
    clang \
    cmake \
    curl \
    file \
    g++ \
    git \
    libtool \
    lld \
    llvm"${LLVM_VERSION}"-dev \
    make \
    samurai \
    patch \
    pkgconf
if [[ "$(clang --version | grep 'clang version ' | sed 's/.* clang version //' | sed 's/\..*//')" != "${LLVM_VERSION}" ]]; then
    exit 1
fi
if [[ "$(cmake --version | grep 'cmake version ' | sed 's/.*cmake version //' | sed -r 's/\.[0-9]+$//')" != "${CMAKE_VERSION}" ]]; then
    exit 1
fi
EOF

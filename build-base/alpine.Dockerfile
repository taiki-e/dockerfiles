# syntax=docker/dockerfile:1.3-labs

ARG ALPINE_VERSION=3.15

# https://pkgs.alpinelinux.org/package/edge/main/x86_64/clang
ARG LLVM_VERSION=12

FROM alpine:"${ALPINE_VERSION}"
SHELL ["/bin/sh", "-eux", "-c"]
ARG LLVM_VERSION
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
    patch
EOF

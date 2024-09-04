# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG MODE
ARG ALPINE_VERSION

FROM alpine:"${ALPINE_VERSION}" AS slim
SHELL ["/bin/sh", "-eux", "-c"]
ARG ALPINE_VERSION
# - As of alpine 3.15, the ninja package is an alias for samurai.
# - Download-related packages (bzip2, curl, dpkg, libarchive-tools, tar, unzip, xz)
#   are not necessarily needed for build, but they are small enough (about 4MB).
RUN <<EOF
case "${ALPINE_VERSION}" in
    edge) ;;
    *)
        cat >>/etc/apk/repositories <<EOF2
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
EOF2
        ;;
esac
cat /etc/apk/repositories
apk --no-cache update -q
apk --no-cache upgrade
apk --no-cache add \
    autoconf \
    automake \
    bash \
    binutils \
    bison \
    bzip2 \
    ca-certificates \
    cmake \
    curl \
    dpkg \
    ed \
    file \
    flex \
    g++ \
    git \
    libarchive-tools \
    libtool \
    make \
    patch \
    pkgconf \
    samurai \
    tar \
    texinfo \
    unzip \
    xz \
    zstd
EOF

# | alpine                    | apt          |
# | ------------------------- | ------------ |
# | clang                     | clang        |
# | clang-dev + clang-static  | libclang-dev |
# | lld                       | lld          |
# | llvm                      | llvm         |
# | llvm*-dev + llvm*-static  | llvm-dev     |
FROM slim AS base
SHELL ["/bin/bash", "-eEuxo", "pipefail", "-c"]
RUN <<EOF
apk --no-cache update -q
apk --no-cache add \
    clang \
    clang-dev \
    clang-static \
    lld
llvm_version=$(clang --version | grep 'clang version' | sed 's/.*clang version //; s/\..*//')
apk --no-cache add \
    llvm"${llvm_version}" \
    llvm"${llvm_version}"-dev \
    llvm"${llvm_version}"-static
gcc --version
clang --version
cmake --version
EOF

FROM "${MODE:-base}" AS final
SHELL ["/bin/bash", "-eEuxo", "pipefail", "-c"]

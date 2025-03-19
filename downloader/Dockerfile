# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG ALPINE_VERSION=3.21

FROM alpine:"${ALPINE_VERSION}"
SHELL ["/bin/sh", "-CeEuxo", "pipefail", "-c"]
RUN <<EOF
apk --no-cache update -q
apk --no-cache upgrade
apk --no-cache add \
    aria2 \
    bash \
    bzip2 \
    ca-certificates \
    curl \
    dpkg \
    file \
    git \
    libarchive-tools \
    lynx \
    tar \
    unzip \
    wget \
    xz \
    zstd
EOF

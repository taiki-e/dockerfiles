# syntax=docker/dockerfile:1.3-labs

FROM alpine

RUN <<EOF
set -ex
apk update
apk --no-cache upgrade
apk add --no-cache \
    aria2 \
    bash \
    bzip2 \
    ca-certificates \
    curl \
    dpkg \
    libarchive-tools \
    wget \
    xz \
    zlib \
    zstd
aria2c --version
curl --version
wget --version
EOF

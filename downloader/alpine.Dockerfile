# syntax=docker/dockerfile:1.3-labs

ARG ALPINE_VERSION=3.14

FROM alpine:"${ALPINE_VERSION}"
SHELL ["/bin/sh", "-eux", "-c"]
RUN <<EOF
apk update --no-cache
apk upgrade --no-cache
apk add --no-cache \
    aria2 \
    bash \
    bzip2 \
    ca-certificates \
    curl \
    dpkg \
    git \
    libarchive-tools \
    unzip \
    wget \
    xz \
    zstd
EOF

# syntax=docker/dockerfile:1.3-labs

ARG ALPINE_VERSION=3.15

FROM alpine:"${ALPINE_VERSION}"
SHELL ["/bin/sh", "-eux", "-c"]
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
    git \
    libarchive-tools \
    unzip \
    wget \
    xz \
    zstd
EOF

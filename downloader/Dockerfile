# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.18

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
    file \
    git \
    libarchive-tools \
    lynx \
    tar \
    unzip \
    wget \
    xz
EOF

# syntax=docker/dockerfile:1.3-labs

ARG UBUNTU_VERSION=20.04

FROM ubuntu:"${UBUNTU_VERSION}"
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
RUN <<EOF
apt-get update
apt-get install -y --no-install-recommends \
    aria2 \
    bzip2 \
    ca-certificates \
    curl \
    git \
    libarchive-tools \
    unzip \
    wget \
    xz-utils \
    zstd
rm -rf \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}
EOF

# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG DISTRO
ARG DISTRO_VERSION
ARG DESKTOP=lxde

FROM "${DISTRO}":"${DISTRO_VERSION}"
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG DISTRO
ARG DISTRO_VERSION
ARG DESKTOP
RUN <<EOF
du -h -d1 /usr/share/
apt-get -o Acquire::Retries=10 -qq update
packages=(
    bzip2
    ca-certificates
    curl
    file
    gcc
    git
    gnupg
    libarchive-tools
    libc6-dev
    nano
    patch
    sudo
    unzip
    wget
    xz-utils
    zsh
)
packages+=(
    novnc
    tigervnc-common
    tigervnc-standalone-server
    websockify
)
packages+=(
    "${DESKTOP}"
)
case "${DISTRO}:${DISTRO_VERSION%-slim}" in
    ubuntu:1[0-9].* | ubuntu:2[0-1].* | debian:1[0-1]) ;;
    *) packages+=(tigervnc-tools) ;;
esac
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    "${packages[@]}"
du -h -d1 /usr/share/
# https://wiki.ubuntu.com/ReducingDiskFootprint#Documentation
find /usr/share/doc -depth -type f ! -name copyright -exec rm -- {} + || true
find /usr/share/doc -empty -exec rmdir -- {} + || true
rm -rf -- \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{groff,info,linda,lintian,man}
# Workaround for OpenJDK installation issue: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199#23
mkdir -p -- /usr/share/man/man1
EOF

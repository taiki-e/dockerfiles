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
apt-get -o Acquire::Retries=10 -qq update
packages=(
    bzip2
    ca-certificates
    curl
    file
    gcc
    git
    gnupg
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
    websockify
)
packages+=(
    "${DESKTOP}"
)
case "${DISTRO}-${DISTRO_VERSION}" in
    ubuntu-1[0-6].*) packages+=(x11vnc) ;;
    ubuntu-*) packages+=(libarchive-tools tigervnc-common tigervnc-standalone-server) ;;
esac
case "${DISTRO}-${DISTRO_VERSION}" in
    ubuntu-1[0-9].* | ubuntu-2[0-1].*) ;;
    ubuntu-*) packages+=(tigervnc-tools) ;;
esac
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    "${packages[@]}"
rm -rf -- \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}
# Workaround for OpenJDK installation issue: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199#23
mkdir -p -- /usr/share/man/man1
EOF

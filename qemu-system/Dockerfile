# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

# TODO: static linking: https://github.com/cross-platform-actions/resources/blob/v0.12.0/ci.rb

ARG UBUNTU_VERSION=24.04

FROM ghcr.io/taiki-e/build-base:ubuntu-"${UBUNTU_VERSION}"-slim AS qemu
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG QEMU_VERSION
ARG BASE_URL=https://download.qemu.org
RUN mkdir -p -- /tmp/qemu-src
RUN <<EOF
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused https://keys.openpgp.org/vks/v1/by-fingerprint/CEACC9E15534EBABB82D3FA03353C9CEF108B584 \
    | gpg --import -
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused -O "${BASE_URL}/qemu-${QEMU_VERSION}.tar.xz"
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused -O "${BASE_URL}/qemu-${QEMU_VERSION}.tar.xz.sig"
gpg --verify "qemu-${QEMU_VERSION}.tar.xz.sig" "qemu-${QEMU_VERSION}.tar.xz"
tar xf "qemu-${QEMU_VERSION}.tar.xz" --strip-components 1 -C /tmp/qemu-src
EOF
RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
du -h -d1 /usr/share/
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    libglib2.0-dev \
    libpixman-1-dev \
    libslirp-dev \
    python3-pip
EOF
RUN --mount=type=bind,source=./qemu.sh,target=/tmp/qemu.sh \
    /tmp/qemu.sh
RUN <<EOF
du -h -d2 /qemu
# https://wiki.ubuntu.com/ReducingDiskFootprint#Documentation
find /qemu/share/doc -depth -type f ! -name copyright -exec rm -- {} + || true
find /qemu/share/doc -empty -exec rmdir -- {} + || true
mkdir -p -- /qemu/share/doc/qemu
cp -- /tmp/qemu-src/COPYING* /tmp/qemu-src/LICENSE* /qemu/share/doc/qemu
rm -rf -- \
    /qemu/share/{groff,info,linda,lintian,man}
du -h -d2 /qemu
EOF

FROM ubuntu:"${UBUNTU_VERSION}"
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
du -h -d1 /usr/share/
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    libpixman-1-0 \
    libslirp0
du -h -d1 /usr/share/
# https://wiki.ubuntu.com/ReducingDiskFootprint#Documentation
find /usr/share/doc -depth -type f ! -name copyright -exec rm -- {} + || true
find /usr/share/doc -empty -exec rmdir -- {} + || true
rm -rf -- \
    /var/log/* \
    /usr/share/{groff,info,linda,lintian,man}
# Workaround for OpenJDK installation issue: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199#23
mkdir -p -- /usr/share/man/man1
du -h -d1 /usr/share/
EOF
COPY --from=qemu /qemu /qemu
ENV PATH="/qemu/bin:$PATH"
RUN <<EOF
qemu-system-x86_64 --version
EOF

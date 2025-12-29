# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG UBUNTU_VERSION=24.04

FROM --platform=amd64 ubuntu:"${UBUNTU_VERSION}" as build
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG ARCH
ARG VALGRIND_REF
RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=bind,source=./default.supp,target=/tmp/default.supp <<EOF
packages=()
packages+=(
    autoconf
    automake
    ca-certificates
    gcc
    git
    libc6-dev
    make
)
mkdir -p -- /valgrind
configure_args=(--prefix=/valgrind/)
export CFLAGS="-O2"
case "${ARCH}" in
    arm64)
        packages+=(g++-aarch64-linux-gnu)
        export CC=aarch64-linux-gnu-gcc
        configure_args+=(--host=aarch64-linux-gnu --enable-only64bit)
        ;;
    armhf)
        packages+=(g++-arm-linux-gnueabihf)
        export CC=arm-linux-gnueabihf-gcc
        export CFLAGS="${CFLAGS} -march=armv7-a -mfloat-abi=hard -mfpu=neon-vfpv4 -marm"
        # export CFLAGS="${CFLAGS} -march=armv8-a -mfloat-abi=hard -mfpu=neon-fp-armv8 -marm"
        configure_args+=(--host=arm-linux-gnueabihf)
        ;;
    i386)
        packages+=(g++-i686-linux-gnu)
        export CC=i686-linux-gnu-gcc
        configure_args+=(--host=i686-linux-gnu)
        ;;
    ppc64el)
        packages+=(g++-powerpc64le-linux-gnu)
        export CC=powerpc64le-linux-gnu-gcc
        configure_args+=(--host=powerpc64le-linux-gnu --enable-only64bit)
        ;;
    riscv64)
        packages+=(g++-riscv64-linux-gnu)
        export CC=riscv64-linux-gnu-gcc
        configure_args+=(--host=riscv64-linux-gnu --enable-only64bit)
        ;;
    s390x)
        packages+=(g++-s390x-linux-gnu)
        export CC=s390x-linux-gnu-gcc
        configure_args+=(--host=s390x-linux-gnu --enable-only64bit)
        ;;
    *) configure_args+=(--enable-only64bit)
esac
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    "${packages[@]}"
(
    cd -- tmp
    git clone git://sourceware.org/git/valgrind.git
    cd -- valgrind
    git checkout "${VALGRIND_REF}"
    ./autogen.sh
    ./configure "${configure_args[@]}"
    make -j"$(nproc)"
    make -j"$(nproc)" install
)
mkdir -p -- /valgrind/share/doc/valgrind
cp -- /tmp/valgrind/COPYING /valgrind/share/doc/valgrind
rm -rf -- /tmp/valgrind
cat -- /tmp/default.supp >>/valgrind/libexec/valgrind/default.supp
du -h -d1 /valgrind/
EOF

FROM ubuntu:"${UBUNTU_VERSION}" as dist
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
COPY --from=build /valgrind /valgrind

FROM ubuntu:"${UBUNTU_VERSION}"
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG ARCH
ARG ENV
RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
du -h -d1 /usr/share/
packages=()
case "${ARCH}" in
    i386)
        dpkg --add-architecture "${ARCH}"
        packages+=(g++-i686-linux-gnu libc6-dbg:"${ARCH}")
        ;;
    armhf)
        dpkg --add-architecture "${ARCH}"
        packages+=(g++-arm-linux-gnueabihf libstdc++6:"${ARCH}" libc6-dbg:"${ARCH}")
        ;;
    *) packages+=(libc6-dbg) ;;
esac
case "${ENV}" in
    cross) ;;
    *) packages+=(ca-certificates curl g++ git) ;;
esac
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    "${packages[@]}"
du -h -d1 /usr/share/
# https://wiki.ubuntu.com/ReducingDiskFootprint#Documentation
find /usr/share/doc -depth -type f ! -name copyright ! -name COPYING -exec rm -- {} + || true
find /usr/share/doc -empty -exec rmdir -- {} + || true
rm -rf -- \
    /var/log/* \
    /usr/share/{groff,info,linda,lintian,man}
# Workaround for OpenJDK installation issue: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199#23
mkdir -p -- /usr/share/man/man1
du -h -d1 /usr/share/
EOF
COPY --from=build /valgrind/. /usr/
ENV VALGRIND_LIB=/usr/libexec/valgrind
RUN <<EOF
case "${ARCH}" in
    i386 | armhf) ;;
    *) valgrind --version ;;
esac
EOF

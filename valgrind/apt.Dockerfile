# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG DISTRO
ARG DISTRO_VERSION

FROM "${DISTRO}":"${DISTRO_VERSION}"
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG DISTRO
ARG DISTRO_VERSION
ARG ARCH
RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
du -h -d1 /usr/share/
packages=()
case "${ARCH}" in
    amd64 | arm64 | i386 | armhf) packages+=(ca-certificates g++ git) ;;
esac
case "${ARCH}" in
    i386)
        dpkg --add-architecture "${ARCH}"
        packages+=(g++-i686-linux-gnu valgrind:"${ARCH}")
        ;;
    armhf)
        dpkg --add-architecture "${ARCH}"
        packages+=(g++-arm-linux-gnueabihf valgrind:"${ARCH}")
        ;;
    riscv64) packages+=(ca-certificates curl libc6-dbg) ;;
    *) packages+=(valgrind) ;;
esac
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    "${packages[@]}"
case "${ARCH}" in
    riscv64)
        # https://bugs.launchpad.net/ubuntu/+source/valgrind/+bug/2120873
        curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-all-errors -o valgrind-riscv64.deb https://launchpad.net/~jchittum/+archive/ubuntu/valgrind-riscv-2120873/+build/31091443/+files/valgrind_3.25.1-0ubuntu2~ppa1_riscv64.deb
        dpkg -i valgrind-riscv64.deb
        rm -- valgrind-riscv64.deb
        apt-get -qq -o Dpkg::Use-Pty=0 purge -y ca-certificates curl
        apt-get -qq -o Dpkg::Use-Pty=0 autoremove -y --purge
        ;;
esac
du -h -d1 /usr/share/
# https://wiki.ubuntu.com/ReducingDiskFootprint#Documentation
find /usr/share/doc -depth -type f ! -name copyright -exec rm -- {} + || true
find /usr/share/doc -empty -exec rmdir -- {} + || true
rm -rf -- \
    /var/log/* \
    /usr/share/{groff,info,linda,lintian,man}
# Workaround for OpenJDK installation issue: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199#23
mkdir -p -- /usr/share/man/man1
EOF

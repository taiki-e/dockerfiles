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
ARG ENV
RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=bind,source=./default.supp,target=/tmp/default.supp <<EOF
du -h -d1 /usr/share/
packages=()
case "${ENV}" in
    cross)
        case "${ARCH}" in
            riscv64) packages+=(autoconf automake ca-certificates gcc git libc6-dev make) ;;
        esac
        ;;
    *) packages+=(ca-certificates curl g++ git) ;;
esac
case "${ARCH}" in
    i386)
        dpkg --add-architecture "${ARCH}"
        packages+=(g++-i686-linux-gnu valgrind:"${ARCH}")
        ;;
    armhf)
        dpkg --add-architecture "${ARCH}"
        packages+=(g++-arm-linux-gnueabihf libstdc++6:"${ARCH}" valgrind:"${ARCH}")
        ;;
    riscv64) packages+=(libc6-dbg) ;;
    *) packages+=(valgrind) ;;
esac
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    "${packages[@]}"
case "${ARCH}" in
    riscv64)
        # Build Valgrind from source to pick https://sourceware.org/git/?p=valgrind.git;a=commit;h=97831bbbc208f3c574095770aff9b19e5a2c6aae
        git clone git://sourceware.org/git/valgrind.git
        (
            cd -- valgrind
            git checkout 97831bbbc208f3c574095770aff9b19e5a2c6aae
            ./autogen.sh
            ./configure --prefix=/usr/
            make -j"$(nproc)"
            make -j"$(nproc)" install
        )
        mkdir -p -- /usr/share/doc/valgrind
        cp -- valgrind/COPYING /usr/share/doc/valgrind
        rm -rf -- valgrind
        case "${ENV}" in
            cross)
                apt-get -qq -o Dpkg::Use-Pty=0 purge -y autoconf automake ca-certificates gcc git libc6-dev make
                apt-get -qq -o Dpkg::Use-Pty=0 autoremove -y --purge
                ;;
        esac
        ;;
esac
case "${ARCH}" in
    i386 | armhf) ;;
    *) valgrind --version ;;
esac
cat -- /tmp/default.supp >>/usr/libexec/valgrind/default.supp
du -h -d1 /usr/share/
# https://wiki.ubuntu.com/ReducingDiskFootprint#Documentation
find /usr/share/doc -depth -type f ! -name copyright ! -name COPYING -exec rm -- {} + || true
find /usr/share/doc -empty -exec rmdir -- {} + || true
rm -rf -- \
    /var/log/* \
    /usr/share/{groff,info,linda,lintian,man}
# Workaround for OpenJDK installation issue: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199#23
mkdir -p -- /usr/share/man/man1
EOF

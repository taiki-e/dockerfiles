# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG UBUNTU_VERSION=24.04

FROM ghcr.io/taiki-e/build-base:ubuntu-"${UBUNTU_VERSION}"-slim AS binutils
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG BINUTILS_VERSION
ARG BASE_URL=https://ftp.gnu.org/gnu/binutils
# ARG BASE_URL=https://sourceware.org/pub/binutils/releases
RUN mkdir -p -- /tmp/binutils-src
RUN <<EOF
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused https://ftp.gnu.org/gnu/gnu-keyring.gpg \
    | gpg --import -
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused -O "${BASE_URL}/binutils-${BINUTILS_VERSION}.tar.xz"
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused -O "${BASE_URL}/binutils-${BINUTILS_VERSION}.tar.xz.sig"
gpg --verify "binutils-${BINUTILS_VERSION}.tar.xz.sig" "binutils-${BINUTILS_VERSION}.tar.xz"
tar xf "binutils-${BINUTILS_VERSION}.tar.xz" --strip-components 1 -C /tmp/binutils-src
EOF
RUN --mount=type=bind,source=./binutils.sh,target=/tmp/binutils.sh \
    /tmp/binutils.sh
ARG MODE
RUN <<EOF
du -h -d2 /binutils
# https://wiki.ubuntu.com/ReducingDiskFootprint#Documentation
find /binutils/share/doc -depth -type f ! -name copyright -exec rm -- {} + || true
find /binutils/share/doc -empty -exec rmdir -- {} + || true
mkdir -p -- /binutils/share/doc/binutils
cp -- /tmp/binutils-src/COPYING* /binutils/share/doc/binutils
rm -rf -- \
    /binutils/share/{groff,info,linda,lintian,man}
du -h -d2 /binutils
dpkg_arch=$(dpkg --print-architecture)
case "${dpkg_arch##*-}" in
    amd64) target=x86_64-pc-linux-gnu ;;
    arm64) target=aarch64-unknown-linux-gnu ;;
    *) printf >&2 '%s\n' "unsupported architecture '${dpkg_arch}'" && exit 1 ;;
esac
if [[ "${MODE}" != "binutils" ]]; then
    for tool in /binutils/bin/*; do
        name="${tool##*/}"
        if [[ "${name}" != "${MODE}" ]]; then
            rm -- "${tool}"
        fi
    done
    for tool in /binutils/"${target}"/bin/*; do
        name="${tool##*/}"
        if [[ "${name}" != "${MODE}" ]]; then
            rm -- "${tool}"
        fi
    done
    rm -rf -- /binutils/{lib,include,etc,"${target}"}
    find /binutils
fi
du -h -d2 /binutils
EOF

FROM ubuntu:"${UBUNTU_VERSION}"
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_VERSION
ARG MODE
RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
du -h -d1 /usr/share/
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg
codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
# shellcheck disable=SC2174
mkdir -pm755 -- /etc/apt/keyrings
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused https://apt.llvm.org/llvm-snapshot.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/llvm-snapshot.gpg
printf '%s\n' "deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-${LLVM_VERSION} main" \
    >"/etc/apt/sources.list.d/llvm-toolchain-${codename}-${LLVM_VERSION}.list"
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    llvm-"${LLVM_VERSION}"
if [[ "${MODE}" != "binutils" ]]; then
    for tool in /usr/lib/llvm-"${LLVM_VERSION}"/bin/*; do
        name="${tool##*/}"
        if [[ "${name}" != "llvm-${MODE}" ]]; then
            rm -- "${tool}" "/usr/bin/${name}-${LLVM_VERSION}"
        fi
    done
fi
for tool in /usr/bin/llvm-*-"${LLVM_VERSION}"; do
    link="${tool%"-${LLVM_VERSION}"}"
    update-alternatives --install "${link}" "${link##*/}" "${tool}" 100
done
apt-get -qq -o Dpkg::Use-Pty=0 purge -y \
    ca-certificates \
    curl \
    gnupg
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
COPY --from=binutils /binutils/. /usr/local/
RUN <<EOF
objdump --version
objdump --help
llvm-objdump --version
llvm-objdump --help
EOF

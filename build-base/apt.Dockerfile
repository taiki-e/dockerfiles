# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG MODE
ARG DISTRO
ARG DISTRO_VERSION

# https://github.com/Kitware/CMake/releases
ARG CMAKE_VERSION=3.31.5
# https://apt.llvm.org
# TODO: update to 19
ARG LLVM_VERSION=15

FROM ghcr.io/taiki-e/downloader AS cmake
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG CMAKE_VERSION
RUN <<EOF
dpkg_arch=$(dpkg --print-architecture)
case "${dpkg_arch##*-}" in
    amd64) cmake_arch=x86_64 ;;
    arm64) cmake_arch=aarch64 ;;
    *) printf >&2 '%s\n' "unsupported architecture '${dpkg_arch}'" && exit 1 ;;
esac
mkdir -p -- cmake
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz" \
    | tar xzf - --strip-components 1 -C /cmake
rm -rf -- \
    /cmake/{doc,man} \
    /cmake/bin/cmake-gui
EOF

FROM "${DISTRO}":"${DISTRO_VERSION}" AS slim
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
# - Download-related packages (bzip2, curl, gnupg, libarchive-tools, unzip, xz-utils)
#   are not necessarily needed for build, but they are small enough (< 10MB).
RUN <<EOF
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    autoconf \
    automake \
    binutils \
    bison \
    bzip2 \
    ca-certificates \
    curl \
    ed \
    file \
    flex \
    g++ \
    git \
    gnupg \
    libarchive-tools \
    libtool \
    make \
    ninja-build \
    patch \
    pkg-config \
    texinfo \
    unzip \
    xz-utils \
    zstd
rm -rf -- \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}
# Workaround for OpenJDK installation issue: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199#23
mkdir -p -- /usr/share/man/man1
gcc --version
EOF

FROM slim AS base
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG DISTRO_VERSION
ARG LLVM_VERSION
RUN <<EOF
case "${DISTRO_VERSION}" in
    18.04) LLVM_VERSION=13 ;;
    24.04 | testing*) LLVM_VERSION=18 ;;
esac
case "${DISTRO_VERSION}" in
    # LLVM version of ubuntu 24.04 is 18
    rolling | devel | testing* | sid* | 24.04) ;;
    *)
        codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
        # shellcheck disable=SC2174
        mkdir -pm755 -- /etc/apt/keyrings
        curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused https://apt.llvm.org/llvm-snapshot.gpg.key \
            | gpg --dearmor >/etc/apt/keyrings/llvm-snapshot.gpg
        printf '%s\n' "deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-${LLVM_VERSION} main" \
            >"/etc/apt/sources.list.d/llvm-toolchain-${codename}-${LLVM_VERSION}.list"
        ;;
esac
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    clang-"${LLVM_VERSION}" \
    libc++-"${LLVM_VERSION}"-dev \
    libc++abi-"${LLVM_VERSION}"-dev \
    libclang-"${LLVM_VERSION}"-dev \
    lld-"${LLVM_VERSION}" \
    llvm-"${LLVM_VERSION}" \
    llvm-"${LLVM_VERSION}"-dev
for tool in /usr/bin/clang*-"${LLVM_VERSION}" /usr/bin/llvm-*-"${LLVM_VERSION}" /usr/bin/*lld*-"${LLVM_VERSION}" /usr/bin/wasm-ld-"${LLVM_VERSION}"; do
    link="${tool%"-${LLVM_VERSION}"}"
    update-alternatives --install "${link}" "${link##*/}" "${tool}" 100
done
rm -rf -- \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}
# Workaround for OpenJDK installation issue: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199#23
mkdir -p -- /usr/share/man/man1
clang --version
EOF

FROM "${MODE:-base}" AS test
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
COPY --from=cmake /cmake /cmake
RUN /cmake/bin/cmake --version

FROM "${MODE:-base}" AS final
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
COPY --from=test /cmake/. /usr/local/

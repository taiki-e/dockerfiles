# syntax=docker/dockerfile:1.3-labs

ARG MODE=base
ARG DISTRO=ubuntu
ARG DISTRO_VERSION=20.04

# https://github.com/Kitware/CMake/releases
ARG CMAKE_VERSION=3.21.4
# https://apt.llvm.org
ARG LLVM_VERSION=12

FROM ghcr.io/taiki-e/downloader as downloader
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG CMAKE_VERSION
RUN <<EOF
dpkg_arch="$(dpkg --print-architecture)"
case "${dpkg_arch##*-}" in
    amd64) cmake_arch=x86_64 ;;
    arm64) cmake_arch=aarch64 ;;
    *) echo >&2 "unsupported architecture '${dpkg_arch}'" && exit 1 ;;
esac
mkdir -p cmake
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz" \
    | tar xzf - --strip-components 1 -C /cmake
rm -rf \
    /cmake/{doc,man} \
    /cmake/bin/cmake-gui
EOF

FROM "${DISTRO}":"${DISTRO_VERSION}" as slim
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
# - Download-related packages (bzip2, curl, gnupg, libarchive-tools, unzip, xz-utils)
#   are not necessarily needed for build, but they are small enough (< 10MB).
RUN <<EOF
apt-get -o Acquire::Retries=10 update -qq
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    autoconf \
    automake \
    binutils \
    bzip2 \
    ca-certificates \
    curl \
    file \
    g++ \
    git \
    gnupg \
    libarchive-tools \
    libtool \
    make \
    ninja-build \
    pkg-config \
    unzip \
    xz-utils
rm -rf \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}
EOF

FROM slim as base
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_VERSION
RUN <<EOF
codename="$(grep </etc/os-release '^VERSION_CODENAME=' | sed 's/^VERSION_CODENAME=//')"
cat >/etc/apt/sources.list.d/llvm.list <<EOF2
deb http://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-${LLVM_VERSION} main
deb-src http://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-${LLVM_VERSION} main
EOF2
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
apt-get -o Acquire::Retries=10 update -qq
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    clang-"${LLVM_VERSION}" \
    libc++-"${LLVM_VERSION}"-dev \
    libc++abi-"${LLVM_VERSION}"-dev \
    lld-"${LLVM_VERSION}" \
    llvm-"${LLVM_VERSION}"
for tool in /usr/bin/clang*-"${LLVM_VERSION}" /usr/bin/llvm-*-"${LLVM_VERSION}" /usr/bin/*lld*-"${LLVM_VERSION}" /usr/bin/wasm-ld-"${LLVM_VERSION}"; do
    link="${tool%"-${LLVM_VERSION}"}"
    update-alternatives --install "${link}" "${link##*/}" "${tool}" 10
done
rm -rf \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}
gcc --version
clang --version
EOF

FROM "${MODE:-base}"
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
COPY --from=downloader /cmake/. /usr/local/

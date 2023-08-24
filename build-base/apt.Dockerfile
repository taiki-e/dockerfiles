# syntax=docker/dockerfile:1

ARG MODE=base
ARG DISTRO=ubuntu
ARG DISTRO_VERSION=22.04

# https://github.com/Kitware/CMake/releases
ARG CMAKE_VERSION=3.27.4
# https://apt.llvm.org
ARG LLVM_VERSION=15

FROM ghcr.io/taiki-e/downloader as cmake
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG CMAKE_VERSION
RUN <<EOF
dpkg_arch=$(dpkg --print-architecture)
case "${dpkg_arch##*-}" in
    amd64) cmake_arch=x86_64 ;;
    arm64) cmake_arch=aarch64 ;;
    *) echo >&2 "unsupported architecture '${dpkg_arch}'" && exit 1 ;;
esac
mkdir -p cmake
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz" \
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
apt-get -o Acquire::Retries=10 -qq update
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
    patch \
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
ARG DISTRO_VERSION
ARG LLVM_VERSION
RUN <<EOF
case "${DISTRO_VERSION}" in
    rolling | sid*) ;;
    *)
        curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
        codename=$(grep '^VERSION_CODENAME=' /etc/os-release | sed 's/^VERSION_CODENAME=//')
        cat >/etc/apt/sources.list.d/llvm.list <<EOF2
deb https://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-${LLVM_VERSION} main
deb-src https://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-${LLVM_VERSION} main
EOF2
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
rm -rf \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}
gcc --version
clang --version
EOF

FROM "${MODE:-base}" as test
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
COPY --from=cmake /cmake /cmake
RUN <<EOF
/cmake/bin/cmake --version
EOF

FROM "${MODE:-base}" as final
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
COPY --from=test /cmake/. /usr/local/

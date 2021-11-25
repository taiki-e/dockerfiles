# syntax=docker/dockerfile:1.3-labs

ARG UBUNTU_VERSION=20.04

# https://github.com/Kitware/CMake/releases
# Use the same major & minor version as alpine: https://pkgs.alpinelinux.org/package/edge/main/x86_64/cmake
ARG CMAKE_VERSION=3.21.4
# https://apt.llvm.org
# Use the same major version as alpine: https://pkgs.alpinelinux.org/package/edge/main/x86_64/clang
ARG LLVM_VERSION=12

FROM ghcr.io/taiki-e/downloader as downloader
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG CMAKE_VERSION
RUN <<EOF
dpkg_arch="$(dpkg --print-architecture)"
case "${dpkg_arch##*-}" in
    amd64) cmake_arch=x86_64 ;;
    arm64) cmake_arch=aarch64 ;;
    *)
        echo >&2 "unsupported architecture '${dpkg_arch}'"
        exit 1
        ;;
esac
mkdir -p cmake
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz" \
    | tar xzf - --strip-components 1 -C /cmake
rm -rf \
    /cmake/{doc,man} \
    /cmake/bin/cmake-gui
EOF

FROM ubuntu:"${UBUNTU_VERSION}"
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_VERSION
RUN <<EOF
apt-get -o Dpkg::Use-Pty=0 update -qq
apt-get -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    autoconf \
    automake \
    binutils \
    ca-certificates \
    curl \
    file \
    g++ \
    git \
    gnupg \
    libtool \
    make \
    ninja-build \
    pkg-config
ubuntu_codename="$(grep </etc/os-release '^UBUNTU_CODENAME=' | sed 's/^UBUNTU_CODENAME=//')"
cat >/etc/apt/sources.list.d/llvm.list <<EOF2
deb http://apt.llvm.org/${ubuntu_codename}/ llvm-toolchain-${ubuntu_codename}-${LLVM_VERSION} main
deb-src http://apt.llvm.org/${ubuntu_codename}/ llvm-toolchain-${ubuntu_codename}-${LLVM_VERSION} main
EOF2
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
apt-get -o Dpkg::Use-Pty=0 update -qq
apt-get -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    clang-"${LLVM_VERSION}" \
    libc++-"${LLVM_VERSION}"-dev \
    libc++abi-"${LLVM_VERSION}"-dev \
    libclang-"${LLVM_VERSION}"-dev \
    lld-"${LLVM_VERSION}" \
    llvm-"${LLVM_VERSION}"-dev
for tool in /usr/bin/clang* /usr/bin/llvm-* /usr/bin/*lld-* /usr/bin/wasm-ld-*; do
    ln -s "${tool}" "${tool%"-${LLVM_VERSION}"}"
done
apt-get -o Dpkg::Use-Pty=0 purge -y --auto-remove \
    curl \
    gnupg
rm -rf \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}
EOF
COPY --from=downloader /cmake/. /usr/local/

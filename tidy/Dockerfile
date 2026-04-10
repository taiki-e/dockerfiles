# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG UBUNTU_VERSION=24.04
ARG LLVM_VERSION=22
ARG NODE_VERSION=24

FROM ubuntu:"${UBUNTU_VERSION}"
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH="/usr/local/cargo/bin:/usr/local/node/bin:/usr/local/venv/bin:$PATH"
ARG LLVM_VERSION
ARG NODE_VERSION
RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=bind,source=./install.sh,target=/tmp/install.sh <<EOF
du -h -d1 /usr/share/
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    libstdc++6 \
    python3-venv \
    xz-utils
du -h -d1 /usr/share/

codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
# shellcheck disable=SC2174
mkdir -pm755 -- /etc/apt/keyrings
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-all-errors https://apt.llvm.org/llvm-snapshot.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/llvm-snapshot.gpg
printf '%s\n' "deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] https://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-${LLVM_VERSION} main" \
    >"/etc/apt/sources.list.d/llvm-toolchain-${codename}-${LLVM_VERSION}.list"
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-all-errors https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
printf '%s\n' "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" \
    >"/etc/apt/sources.list.d/nodesource-${NODE_VERSION}.list"
apt-get -o Acquire::Retries=10 -qq update
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    clang-format-"${LLVM_VERSION}" \
    nodejs
for tool in /usr/bin/clang*-"${LLVM_VERSION}"; do
    link="${tool%"-${LLVM_VERSION}"}"
    update-alternatives --install "${link}" "${link##*/}" "${tool}" 100
done
clang-format --version
npm --version
# We need to use nightly rustfmt because we use the unstable formatting options of rustfmt.
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-all-errors https://sh.rustup.rs \
  | sh -s -- -y --profile minimal --default-toolchain nightly --no-modify-path --component rustfmt
chmod -R a+w "${RUSTUP_HOME}" "${CARGO_HOME}"
rustc --version
cargo --version
rustup --version
mkdir -p -- install-action
(
    cd -- install-action
    git clone https://github.com/taiki-e/install-action.git --branch manifest-schema-0.2 manifests
    (
        cd -- manifests
        commit=$({ git --no-pager log --before="14 days ago" || true; } | head -1 | cut -d' ' -f2)
        git checkout "${commit}"
    )
    cp -- /tmp/install.sh ./
    INPUT_TOOL=parse-dockerfile,shfmt,shellcheck,taplo,zizmor \
        ./install.sh
)
rm -rf -- install-action
dpkg_arch=$(dpkg --print-architecture)
# https://github.com/PowerShell/PowerShell/releases
pwsh_version=7.6.0
case "${dpkg_arch##*-}" in
    amd64)
        pwsh_arch=x64
        hash=04517472cf57d7f9cbd93897da9bed467c73ca6063c29d7655ebc20aa1d6023f
        ;;
    arm64)
        pwsh_arch=arm64
        hash=dddf7564fb3b52dc26be5580fc5b4e08eb3fa65b094488aae6d4b3cad5fea460
        ;;
    *) printf >&2 '%s\n' "unsupported architecture '${dpkg_arch}'" && exit 1 ;;
esac
mkdir -p -- /usr/local/pwsh
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-all-errors -o pwsh.tar.gz "https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-${pwsh_arch}.tar.gz"
sha256sum -c <<<"${hash}  pwsh.tar.gz"
tar xf pwsh.tar.gz -C /usr/local/pwsh
rm -- pwsh.tar.gz
chmod +x /usr/local/pwsh/pwsh
ln -s -- /usr/local/pwsh/pwsh /usr/local/bin/pwsh

apt-get -qq -o Dpkg::Use-Pty=0 purge -y \
    curl \
    gnupg \
    xz-utils
du -h -d1 /usr/share
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
RUN <<EOF
npm config set min-release-age=14 --location=global
npm config set ignore-scripts=true --location=global
npm config set allow-git=none --location=global
npm config set engine-strict=true --location=global
npm config set strict-peer-deps=true --location=global
npm install cspell --location=global
npm install prettier --location=global
npm install markdownlint-cli2 --location=global
EOF
RUN <<EOF
python3 -m venv /usr/local/venv
/usr/local/venv/bin/pip --version
# --uploaded-prior-to requires pip 26.0.
/usr/local/venv/bin/pip install --upgrade pip
/usr/local/venv/bin/pip install --uploaded-prior-to="$(date -d '-14days' -Idate)" yq
EOF
RUN <<EOF
pwsh -Command 'Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name PSScriptAnalyzer -Scope AllUsers; Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted'
EOF
COPY /checks /checks

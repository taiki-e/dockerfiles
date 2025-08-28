# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0 OR MIT

ARG ALPINE_VERSION=3.22

ARG QEMU_DPKG_VERSION

FROM ghcr.io/taiki-e/downloader AS downloader
SHELL ["/bin/bash", "-CeEuxo", "pipefail", "-c"]
ARG QEMU_DPKG_VERSION
RUN <<EOF
dpkg_arch=$(dpkg --print-architecture)
mkdir -p -- /tmp/qemu /qemu
case "${QEMU_DPKG_VERSION}" in
    [0-8].* | 9.0.*) static='-static' ;;
esac
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "https://ftp.debian.org/debian/pool/main/q/qemu/qemu-user${static:-}_${QEMU_DPKG_VERSION}_${dpkg_arch##*-}.deb" \
    | dpkg-deb -xv - /tmp/qemu
(
    cd -- /tmp/qemu/usr/bin
    set +x
    for tool in qemu-*; do
        # ignore symbolic links
        [[ -L "${tool}" ]] || mv -- "${tool}" /qemu/"${tool%-static}"
    done
)
file /qemu/qemu-*
if file /qemu/qemu-* | grep -Fq 'dynamically linked'; then
    exit 1
fi
EOF

FROM alpine:"${ALPINE_VERSION}" AS final
SHELL ["/bin/sh", "-CeEuxo", "pipefail", "-c"]
COPY --from=downloader /qemu/. /usr/bin

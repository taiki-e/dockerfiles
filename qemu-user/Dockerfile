# syntax=docker/dockerfile:1.3-labs

ARG ALPINE_VERSION=3.16

# https://ftp.debian.org/debian/pool/main/q/qemu
ARG QEMU_DPKG_VERSION=7.1+dfsg-2+b3

FROM ghcr.io/taiki-e/downloader as downloader
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG QEMU_DPKG_VERSION
RUN <<EOF
dpkg_arch="$(dpkg --print-architecture)"
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "https://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${QEMU_DPKG_VERSION}_${dpkg_arch##*-}.deb" \
    | dpkg-deb --fsys-tarfile - \
    | tar xf - --strip-components 3 -C /usr/bin --wildcards ./usr/bin/qemu-*-static
set +x
for tool in /usr/bin/qemu-*-static; do
    mv "${tool}" "${tool%-static}"
done
set -x
apk --no-cache add file
file /usr/bin/qemu-*
if file /usr/bin/qemu-* | grep -Eq 'dynamically linked'; then
    exit 1
fi
EOF

FROM alpine:"${ALPINE_VERSION}" as final
SHELL ["/bin/sh", "-eux", "-c"]
COPY --from=downloader /usr/bin/qemu-* /usr/bin

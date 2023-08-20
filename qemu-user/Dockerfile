# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.18

ARG QEMU_DPKG_VERSION

FROM ghcr.io/taiki-e/downloader as downloader
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
ARG QEMU_DPKG_VERSION
RUN <<EOF
dpkg_arch=$(dpkg --print-architecture)
if [[ "${QEMU_DPKG_VERSION}" == "8.1.0~rc4+ds-2" ]]; then
    case "${dpkg_arch##*-}" in
        arm64) QEMU_DPKG_VERSION='8.1.0~rc4+ds-1' ;;
    esac
fi
mkdir -p /tmp/qemu
mkdir -p /qemu
curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "https://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${QEMU_DPKG_VERSION}_${dpkg_arch##*-}.deb" \
    | dpkg-deb --fsys-tarfile - \
    | tar xf - -C /tmp/qemu
(
    cd /tmp/qemu/usr/bin
    set +x
    for tool in qemu-*; do
        # ignore symbolic links
        [[ -L "${tool}" ]] || mv "${tool}" /qemu/"${tool%-static}"
    done
)
file /qemu/qemu-*
if file /qemu/qemu-* | grep -Eq 'dynamically linked'; then
    exit 1
fi
EOF

FROM alpine:"${ALPINE_VERSION}" as final
SHELL ["/bin/sh", "-eux", "-c"]
COPY --from=downloader /qemu/. /usr/bin

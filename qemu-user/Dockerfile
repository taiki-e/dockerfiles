# syntax=docker/dockerfile:1.3-labs

ARG ALPINE_VERSION=3.15

# https://pkgs.alpinelinux.org/package/edge/community/x86_64/qemu
ARG QEMU_VERSION=6.1.0

FROM alpine:"${ALPINE_VERSION}" as base
SHELL ["/bin/sh", "-eux", "-c"]
ARG QEMU_VERSION
# architecture list: https://git.alpinelinux.org/aports/tree/community/qemu/APKBUILD
RUN <<EOF
apk --no-cache update -q
apk --no-cache upgrade
cat >>/etc/apk/repositories <<EOF2
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/main
EOF2
apk --no-cache add \
    file \
    qemu-aarch64 \
    qemu-aarch64_be \
    qemu-alpha \
    qemu-arm \
    qemu-armeb \
    qemu-cris \
    qemu-hppa \
    qemu-i386 \
    qemu-m68k \
    qemu-microblaze \
    qemu-microblazeel \
    qemu-mips \
    qemu-mips64 \
    qemu-mips64el \
    qemu-mipsel \
    qemu-mipsn32 \
    qemu-mipsn32el \
    qemu-nios2 \
    qemu-or1k \
    qemu-ppc \
    qemu-ppc64 \
    qemu-ppc64le \
    qemu-riscv32 \
    qemu-riscv64 \
    qemu-s390x \
    qemu-sh4 \
    qemu-sh4eb \
    qemu-sparc \
    qemu-sparc32plus \
    qemu-sparc64 \
    qemu-x86_64 \
    qemu-xtensa \
    qemu-xtensaeb
if [[ "$(qemu-aarch64 --version | grep ' version ' | sed 's/.* version //')" != "${QEMU_VERSION}" ]]; then
    exit 1
fi
file /usr/bin/qemu-*
if file /usr/bin/qemu-* | grep -E 'dynamically linked' >/dev/null; then
    exit 1
fi
EOF

FROM alpine:"${ALPINE_VERSION}" as final
SHELL ["/bin/sh", "-eux", "-c"]
COPY --from=base /usr/bin/qemu-* /usr/bin

#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR

set -x

export LDFLAGS="-s ${LDFLAGS:-}"

export CFLAGS="-g0 -O2 -fPIC ${CFLAGS:-}"
export CXXFLAGS="-g0 -O2 -fPIC ${CXXFLAGS:-}"

prefix=/qemu

mkdir -p -- /tmp/qemu-build "${prefix}"
cd -- /tmp/qemu-build
set +C
/tmp/qemu-src/configure --help
args=()
if [[ -n "${QEMU_TARGET:-}" ]]; then
  args+=(--target-list="${QEMU_TARGET}")
fi
# Refs: https://github.com/cross-platform-actions/resources/blob/v0.12.0/ci.rb
args+=(
  --prefix="${prefix}"
  --enable-lto
  --enable-slirp
  --enable-tools
  --disable-auth-pam
  --disable-bochs
  --disable-capstone
  --disable-cfi-debug
  --disable-curses
  --disable-debug-info
  --disable-debug-mutex
  --disable-dmg
  --disable-docs
  --disable-gcrypt
  --disable-gnutls
  --disable-gtk
  --disable-guest-agent
  --disable-guest-agent-msi
  --disable-libiscsi
  --disable-libssh
  --disable-libusb
  --disable-lzo
  --disable-nettle
  --disable-parallels
  --disable-png
  --disable-qcow1
  --disable-qed
  --disable-replication
  --disable-sdl
  --disable-sdl-image
  --disable-smartcard
  --disable-snappy
  --disable-usb-redir
  --disable-user
  --disable-vde
  --disable-vdi
  --disable-vvfat
  --disable-xen
  --disable-zstd
)
/tmp/qemu-src/configure "${args[@]}" &>build.log || (tail <build.log -5000 && exit 1)
make -j"$(nproc)" &>build.log || (tail <build.log -5000 && exit 1)
make -p "${prefix}" &>build.log || (tail <build.log -5000 && exit 1)
make install &>build.log || (tail <build.log -5000 && exit 1)

set +x
for path in "${prefix}"/bin/*; do
  file_info=$(file "${path}")
  if grep -Fq 'not stripped' <<<"${file_info}"; then
    strip "${path}"
  fi
done
set -x
file "${prefix}"/bin/*

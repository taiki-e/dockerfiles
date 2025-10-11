#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR

set -x

export CC="gcc -static --static"
export CXX="g++ -static --static"
export LDFLAGS="-s -static --static ${LDFLAGS:-}"

export CFLAGS="-g0 -O2 -fPIC ${CFLAGS:-}"
export CXXFLAGS="-g0 -O2 -fPIC ${CXXFLAGS:-}"

prefix=/binutils

mkdir -p -- /tmp/binutils-build "${prefix}"
cd -- /tmp/binutils-build
set +C
/tmp/binutils-src/configure \
  --prefix="${prefix}" \
  --enable-targets=all \
  --with-debug-prefix-map="$(pwd)"= \
  --disable-nls \
  &>build.log || (tail <build.log -5000 && exit 1)
make -j"$(nproc)" &>build.log || (tail <build.log -5000 && exit 1)
make -p "${prefix}" &>build.log || (tail <build.log -5000 && exit 1)
make install &>build.log || (tail <build.log -5000 && exit 1)

set +x
for path in "${prefix}"/bin/*; do
  file_info=$(file "${path}")
  if grep -Fq 'not stripped' <<<"${file_info}"; then
    strip "${path}"
  fi
  if grep -Fq 'dynamically linked' <<<"${file_info}"; then
    printf '%s\n' "${file_info}"
    printf >&2 '%s\n' "binaries must be statically linked: ${path}"
    exit 1
  fi
done
set -x
file "${prefix}"/bin/*

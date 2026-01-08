#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    ./qemu-system/build-docker.sh

if [[ $# -gt 0 ]]; then
  cat <<EOF
USAGE:
    $0
EOF
  exit 1
fi
package=$(basename -- "$(cd -- "$(dirname -- "$0")" && pwd)")
arch="${HOST_ARCH:-"$(uname -m)"}"
case "${arch}" in
  x86_64 | x86-64 | x64 | amd64)
    docker_arch=amd64
    platform=linux/amd64
    ;;
  aarch64 | arm64)
    docker_arch=arm64v8
    platform=linux/arm64/v8
    ;;
  *) bail "unsupported host architecture '${arch}'" ;;
esac

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh
# shellcheck source-path=SCRIPTDIR/..
. ./qemu-system/shared.sh

build() {
  local dockerfile="${package}/Dockerfile"
  local full_tag="${repository}:${version%.*}-${docker_arch}"
  local build_args=(
    "${opencontainers_labels[@]}"
    --file "${dockerfile}" "${package}/"
    --platform "${platform}"
    --tag "${full_tag}"
    --build-arg "QEMU_VERSION=${version}"
  )

  if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
    x docker buildx build --provenance=false --push "${build_args[@]}" || (printf '%s\n' "info: build log saved at ${log_file}" && exit 1)
    x docker pull "${full_tag}"
    x docker history "${full_tag}"
  elif [[ "${platform}" == *","* ]]; then
    x docker buildx build --provenance=false "${build_args[@]}" || (printf '%s\n' "info: build log saved at ${log_file}" && exit 1)
  else
    x docker buildx build --provenance=false --load "${build_args[@]}" || (printf '%s\n' "info: build log saved at ${log_file}" && exit 1)
    x docker history "${full_tag}"
  fi
  x docker system df
}

log_dir="tmp/log/${package}/${version}"
log_file="${log_dir}/build-docker-${time}.log"
mkdir -p -- "${log_dir}"
build 2>&1 | tee -- "${log_file}"
printf '%s\n' "info: build log saved at ${log_file}"
x docker images "${repository}"

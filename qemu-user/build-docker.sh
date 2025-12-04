#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    PLATFORM=linux/amd64 ./qemu-user/build-docker.sh
#    PLATFORM=linux/arm64/v8 ./qemu-user/build-docker.sh

if [[ $# -gt 0 ]]; then
  cat <<EOF
USAGE:
    $0
EOF
  exit 1
fi
package=$(basename -- "$(cd -- "$(dirname -- "$0")" && pwd)")
platform="${PLATFORM:-"linux/amd64,linux/arm64/v8"}"

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh

# https://ftp.debian.org/debian/pool/main/q/qemu
# https://tracker.debian.org/pkg/qemu
latest=10.1
dpkg_versions=(
  10.2.0~rc1+ds-1
  10.1.2+ds-3+b1
  10.0.6+ds-0+deb13u2
)

build() {
  local dockerfile="${package}/Dockerfile"
  local full_tag="${repository}:${version}"
  local build_args=(
    "${opencontainers_labels[@]}"
    --file "${dockerfile}" "${package}/"
    --platform "${platform}"
    --tag "${full_tag}"
    --build-arg "QEMU_DPKG_VERSION=${dpkg_version}"
  )
  if [[ "${version}" == "${latest}" ]]; then
    build_args+=(
      --tag "${repository}:latest"
    )
  fi

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

for dpkg_version in "${dpkg_versions[@]}"; do
  if [[ "${dpkg_version}" =~ ^[1-9][0-9]\.[0-9][\.\+].+ ]]; then
    version="${dpkg_version:0:4}"
  else
    bail "unhandled ${dpkg_version}"
  fi
  log_dir="tmp/log/${package}/${version}"
  log_file="${log_dir}/build-docker-${time}.log"
  mkdir -p -- "${log_dir}"
  build 2>&1 | tee -- "${log_file}"
  printf '%s\n' "info: build log saved at ${log_file}"
done

x docker images "${repository}"

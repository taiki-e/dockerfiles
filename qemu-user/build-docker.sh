#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    ./qemu-user/build-docker.sh

if [[ $# -gt 0 ]]; then
  cat <<EOF
USAGE:
    $0
EOF
  exit 1
fi
package=$(basename -- "$(cd -- "$(dirname -- "$0")" && pwd)")
platform=''
if [[ -n "${PLATFORM:-}" ]]; then
  platform="${PLATFORM}"
elif [[ -n "${CI:-}" ]]; then
  platform=linux/amd64,linux/arm64/v8
fi

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh

# https://ftp.debian.org/debian/pool/main/q/qemu
# https://tracker.debian.org/pkg/qemu
latest=11.0
dpkg_versions=(
  11.0.0+ds-1
  10.2.2+ds-1
  10.0.8+ds-0+deb13u1+b1
)

build() {
  local dockerfile="${package}/Dockerfile"
  local full_tag="${repository}:${version}"
  local build_args=(
    --file "${dockerfile}" "${package}/"
    --tag "${full_tag}"
    --build-arg "ALPINE_VERSION=${alpine_latest}"
    --build-arg "QEMU_DPKG_VERSION=${dpkg_version}"
  )
  if [[ -n "${platform}" ]]; then
    build_args+=(--platform "${platform}")
  fi
  if [[ "${version}" == "${latest}" ]]; then
    build_args+=(
      --tag "${repository}:latest"
    )
  fi

  docker_buildx_build "${full_tag}" "${build_args[@]}"
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
  printf 'info: build log will be saved at %s\n' "${log_file}"
  build 2>&1 | tee -- "${log_file}"
done

x docker images "${repository}"

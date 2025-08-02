#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    ./qemu-user/build-docker.sh

x() {
  (
    set -x
    "$@"
  )
}
bail() {
  printf >&2 'error: %s\n' "$*"
  exit 1
}

if [[ $# -gt 0 ]]; then
  cat <<EOF
USAGE:
    $0
EOF
  exit 1
fi

export DOCKER_BUILDKIT=1
export BUILDKIT_STEP_LOG_MAX_SIZE=10485760

owner="${OWNER:-taiki-e}"
package=$(basename -- "$(cd -- "$(dirname -- "$0")" && pwd)")
repository="ghcr.io/${owner}/${package}"
platform="${PLATFORM:-"linux/amd64,linux/arm64/v8"}"
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

# https://ftp.debian.org/debian/pool/main/q/qemu
# https://tracker.debian.org/pkg/qemu
latest=10.0
dpkg_versions=(
  10.1.0~rc1+ds-3
  10.0.2+ds-2+b1
  7.2+dfsg-7+deb12u14
)

build() {
  local dockerfile="${package}/Dockerfile"
  local full_tag="${repository}:${version}"
  local build_args=(
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
  if [[ "${dpkg_version}" =~ ^[1-9]\.[0-9][\.\+].+ ]]; then
    version="${dpkg_version:0:3}"
  elif [[ "${dpkg_version}" =~ ^[1-9][0-9]\.[0-9][\.\+].+ ]]; then
    version="${dpkg_version:0:4}"
  else
    bail "${dpkg_version}"
  fi
  log_dir="tmp/log/${package}/${version}"
  log_file="${log_dir}/build-docker-${time}.log"
  mkdir -p -- "${log_dir}"
  build 2>&1 | tee -- "${log_file}"
  printf '%s\n' "info: build log saved at ${log_file}"
done

x docker images "${repository}"

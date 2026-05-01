#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

package="$1"
shift
platform=''
if [[ -n "${PLATFORM:-}" ]]; then
  platform="${PLATFORM}"
elif [[ -n "${CI:-}" ]]; then
  platform=linux/amd64,linux/arm64/v8
fi

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh

build() {
  local dockerfile="${package}/Dockerfile"
  local tag="${repository}:latest"
  local build_args=(
    "${opencontainers_labels[@]}"
    --file "${dockerfile}" "${package}/"
    --tag "${tag}"
  )
  if [[ -n "${platform}" ]] && [[ "$*" != *"--platform"* ]]; then
    build_args+=(--platform "${platform}")
  fi
  build_args+=("$@")

  if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
    x docker buildx build --provenance=false --push "${build_args[@]}" || (printf 'info: build log saved at %s\n' "${log_file}" && exit 1)
    x retry docker pull "${tag}"
    x docker history "${tag}"
  elif [[ "${platform}" == *","* ]]; then
    x docker buildx build --provenance=false "${build_args[@]}" || (printf 'info: build log saved at %s\n' "${log_file}" && exit 1)
  else
    x docker buildx build --provenance=false --load "${build_args[@]}" || (printf 'info: build log saved at %s\n' "${log_file}" && exit 1)
    x docker history "${tag}"
  fi
  x docker system df
}

log_dir="tmp/log/${package}"
log_file="${log_dir}/build-docker-${time}.log"
mkdir -p -- "${log_dir}"
build "$@" 2>&1 | tee -- "${log_file}"
printf 'info: build log saved at %s\n' "${log_file}"

x docker images "${repository}"

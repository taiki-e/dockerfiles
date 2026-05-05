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
    --file "${dockerfile}" "${package}/"
    --tag "${tag}"
  )
  if [[ -n "${platform}" ]] && [[ "$*" != *"--platform"* ]]; then
    build_args+=(--platform "${platform}")
  fi
  build_args+=("$@")

  docker_buildx_build "${tag}" "${build_args[@]}"
}

log_dir="tmp/log/${package}"
log_file="${log_dir}/build-docker-${time}.log"
mkdir -p -- "${log_dir}"
printf 'info: build log will be saved at %s\n' "${log_file}"
build "$@" 2>&1 | tee -- "${log_file}"

x docker images "${repository}"

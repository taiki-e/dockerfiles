#!/bin/false
# SPDX-License-Identifier: Apache-2.0 OR MIT
# shellcheck shell=bash # not executable
# shellcheck disable=SC2034

x() {
  (
    set -x
    "$@"
  )
}
retry() {
  for i in {1..10}; do
    if "$@"; then
      return 0
    else
      sleep "${i}"
    fi
  done
  "$@"
}
bail() {
  printf >&2 'error: %s\n' "$*"
  exit 1
}

export DOCKER_BUILDKIT=1
export BUILDKIT_STEP_LOG_MAX_SIZE=10485760

owner="${OWNER:-taiki-e}"
repository="ghcr.io/${owner}/${package:?}"
revision=$(git rev-parse HEAD)
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

docker_buildx_build() {
  local tag="$1"
  shift
  local build_args=(
    --provenance=false
    # https://specs.opencontainers.org/image-spec/annotations/
    --label "org.opencontainers.image.source=https://github.com/${owner}/dockerfiles"
    --label "org.opencontainers.image.revision=${revision}"
    --label "org.opencontainers.image.documentation=https://github.com/${owner}/dockerfiles/blob/${revision}/${package}/README.md"
    "$@"
  )
  if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
    # Note: using oci-mediatypes=true drops labels on https://github.com/<repo>/pkgs/container.
    x docker buildx build --push --output type=image,compression=zstd,compression-level=10,force-compression=true,push=true "${build_args[@]}"
    x retry docker pull "${tag}"
    x docker history "${tag}"
  elif [[ "${platform:-}" == *","* ]]; then
    x docker buildx build "${build_args[@]}"
  else
    x docker buildx build --load "${build_args[@]}"
    x docker history "${tag}"
  fi
  x docker system df
}

# See also tools/container-info.sh
ubuntu_latest=24.04
ubuntu_rolling=25.10
debian_latest=13
alpine_latest=3.23

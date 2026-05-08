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
# https://specs.opencontainers.org/image-spec/annotations/
common_labels=(
  "org.opencontainers.image.source=https://github.com/${owner}/dockerfiles"
  "org.opencontainers.image.revision=${revision}"
  "org.opencontainers.image.documentation=https://github.com/${owner}/dockerfiles/blob/${revision}/${package}/README.md"
)
labels=(
  "${common_labels[@]}"
  "org.opencontainers.image.version="
)
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

docker_buildx_build() {
  local tag="$1"
  shift
  local build_args=(--provenance=false)
  # Note: using oci-mediatypes=true drops labels passed by --label,
  # but is needed for incompatibility with containerd (https://github.com/containerd/containerd/issues/9263).
  # annotation-index also drops labels passed by --label.
  local output='type=image,oci-mediatypes=true'
  for label in "${labels[@]}"; do
    build_args+=(--label "${label}")
    if [[ "${platform:-}" == *","* ]]; then
      output+=",annotation-index.${label}"
    fi
  done
  build_args+=("$@")
  if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
    output+=',compression=zstd,compression-level=10,force-compression=true,push=true'
    x docker buildx build --push --output "${output}" "${build_args[@]}"
    x retry docker pull "${tag}"
    x docker history "${tag}"
  elif [[ "${platform:-}" == *","* ]]; then
    x docker buildx build --output "${output}" "${build_args[@]}"
  else
    x docker buildx build --load --output "${output}" "${build_args[@]}"
    x docker history "${tag}"
  fi
  x docker system df
}

# See also tools/container-info.sh
ubuntu_latest=24.04
ubuntu_rolling=25.10
debian_latest=13
alpine_latest=3.23

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
common_labels=(
  # https://specs.opencontainers.org/image-spec/annotations/
  "org.opencontainers.image.source=https://github.com/${owner}/dockerfiles"
  "org.opencontainers.image.revision=${revision}"
  "org.opencontainers.image.documentation=https://github.com/${owner}/dockerfiles/blob/${revision}/${package}/README.md"
)
labels=(
  "${common_labels[@]}"
  "org.opencontainers.image.version="
)
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

# TODO: Add org.opencontainers.image.* annotations
# annotation-index seems to drop labels passed by --label.
# https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#adding-a-description-to-multi-arch-images
docker_buildx_build() {
  local tag="$1"
  shift
  local build_args=(--provenance=false)
  for label in "${labels[@]}"; do
    build_args+=(--label "${label}")
  done
  build_args+=("$@")
  if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
    local output='type=image,compression=zstd,compression-level=10,force-compression=true,push=true'
    # Note: using oci-mediatypes=true drops labels on https://github.com/<repo>/pkgs/container.
    x docker buildx build --push --output "${output}" "${build_args[@]}"
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

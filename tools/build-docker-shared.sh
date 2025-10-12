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
# https://specs.opencontainers.org/image-spec/annotations/
opencontainers_labels=(
  --label "org.opencontainers.image.source=https://github.com/${owner}/dockerfiles"
  --label "org.opencontainers.image.revision=$(git rev-parse HEAD)"
)
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

# See also tools/container-info.sh
ubuntu_latest=24.04
ubuntu_rolling=25.10
debian_latest=13
alpine_latest=3.22

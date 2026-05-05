#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#   ./binutils/docker-manifest.sh

if [[ $# -gt 0 ]]; then
  cat <<EOF
USAGE:
    $0
EOF
  exit 1
fi
package=$(basename -- "$(cd -- "$(dirname -- "$0")" && pwd)")

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh
# shellcheck source-path=SCRIPTDIR/..
. ./binutils/shared.sh

docker_manifest() {
  local tags=("${repository}:${version}")
  if [[ "${version}" == "${latest}" ]]; then
    tags+=("${repository}:latest")
  fi
  # TODO: Add org.opencontainers.image.* annotations
  # docker manifest command doesn't have option for it, may be blocked by https://github.com/docker/buildx/issues/2956.
  # https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#adding-a-description-to-multi-arch-images
  for tag in "${tags[@]}"; do
    local args=()
    for arch in "${arches[@]}"; do
      args+=("${tag/latest/"${latest}"}-${arch}")
    done
    x docker manifest create --amend "${tag}" "${args[@]}"
    for arch in "${arches[@]}"; do
      case "${arch}" in
        amd64)
          x docker manifest annotate --os linux --arch amd64 "${tag}" "${tag/latest/"${latest}"}-${arch}"
          ;;
        arm64v8)
          x docker manifest annotate --os linux --arch arm64 --variant v8 "${tag}" "${tag/latest/"${latest}"}-${arch}"
          ;;
        *) bail "unsupported architecture '${arch}'" ;;
      esac
    done
  done
  if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
    for tag in "${tags[@]}"; do
      (
        set -x
        retry docker manifest push --purge "${tag}"
      )
    done
  fi
}

for mode in "${modes[@]}"; do
  repository="ghcr.io/${owner}/${mode}"
  arches=(amd64 arm64v8)
  docker_manifest
done

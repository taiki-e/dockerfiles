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

# NB: Sync with build-docker.sh
binutils_version=2.45
llvm_version=21
version="binutils-${binutils_version}-llvm-${llvm_version}"
latest=binutils-2.45-llvm-21

docker_manifest() {
  local tags=("${repository}:${version}")
  if [[ "${version}" == "${latest}" ]]; then
    tags+=("${repository}:latest")
  fi
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

for mode in binutils objdump; do
  repository="ghcr.io/${owner}/${mode}"
  arches=(amd64 arm64v8)
  docker_manifest
done

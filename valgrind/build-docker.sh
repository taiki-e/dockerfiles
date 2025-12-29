#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    ./valgrind/build-docker.sh <ARCH> [DOCKER_BUILD_OPTIONS]

if [[ $# -lt 1 ]]; then
  cat <<EOF
USAGE:
    $0 <DISTRO> [DOCKER_BUILD_OPTIONS]
EOF
  exit 1
fi
arch="$1"
shift
package=$(basename -- "$(cd -- "$(dirname -- "$0")" && pwd)")

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh

# https://valgrind.org/docs/manual/dist.news.html
valgrind_version=3.26.0
valgrind_latest=3.26.0

build() {
  local target="$1"
  shift
  local build_args=()
  local platform
  case "${target}" in
    dist)
      platform=linux/amd64
      build_args+=(--target "${target}")
      ;;
    *)
      target="${env}"
      case "${arch}" in
        amd64 | i386) platform=linux/amd64 ;;
        arm64 | armhf) platform=linux/arm64/v8 ;;
        ppc64el) platform=linux/ppc64le ;;
        riscv64) platform=linux/riscv64 ;;
        s390x) platform=linux/s390x ;;
        *) bail "unrecognized dpkg arch '${arch}'" ;;
      esac
      ;;
  esac
  local dockerfile="${package}/Dockerfile"
  local full_tag="${repository}:${valgrind_version}-${arch}${target:+"-${target}"}"
  local valgrind_ref="${valgrind_version}"
  if [[ "${valgrind_ref}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    valgrind_ref="VALGRIND_${valgrind_ref//\./_}"
  fi
  build_args+=(
    "${opencontainers_labels[@]}"
    --file "${dockerfile}" "${package}/"
    --platform "${platform}"
    --tag "${full_tag}"
    --build-arg "ARCH=${arch}"
    --build-arg "ENV=${env}"
    --build-arg "VALGRIND_REF=${valgrind_ref}"
  )
  if [[ "${valgrind_version}" == "${valgrind_latest}" ]]; then
    build_args+=(
      --tag "${repository}:${arch}${target:+"-${target}"}"
    )
  fi
  build_args+=("$@")

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

log_dir="tmp/log/${package}/${valgrind_version}"
log_file="${log_dir}/build-docker-${arch}-${time}.log"
mkdir -p -- "${log_dir}"
case "${arch}" in
  amd64 | arm64 | armhf | i386) env='' ;;
  ppc64el | riscv64 | s390x) env=cross ;;
  *) bail "unrecognized arch '${arch}'" ;;
esac
build dist "$@" 2>&1 | tee -- "${log_file}"
build - "$@" 2>&1 | tee -- "${log_file}"
printf '%s\n' "info: build log saved at ${log_file}"

x docker images "${repository}"

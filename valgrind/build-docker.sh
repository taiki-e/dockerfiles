#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    ./valgrind/build-docker.sh <DISTRO> [DOCKER_BUILD_OPTIONS]

if [[ $# -lt 1 ]]; then
  cat <<EOF
USAGE:
    $0 <DISTRO> [DOCKER_BUILD_OPTIONS]
EOF
  exit 1
fi
distro="$1"
distro_version="${distro#*:}"
distro="${distro%:*}"
distro_upper=$(tr '[:lower:]' '[:upper:]' <<<"${distro}")
shift
package=$(basename -- "$(cd -- "$(dirname -- "$0")" && pwd)")

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh

host_dpkg_arch=(amd64 arm64 armhf i386)
cross_dpkg_arch=(ppc64el riscv64 s390x)

build() {
  local platform
  case "${arch}" in
    amd64 | i386) platform=linux/amd64 ;;
    arm64 | armhf) platform=linux/arm64/v8 ;;
    ppc64el) platform=linux/ppc64le ;;
    riscv64) platform=linux/riscv64 ;;
    s390x) platform=linux/s390x ;;
    *) bail "unrecognized dpkg arch '${arch}'" ;;
  esac
  local dockerfile="${package}/${base}.Dockerfile"
  local full_tag="${repository}:${distro}-${distro_version/-slim/}-${arch}${env:+"-${env}"}"
  local build_args=(
    "${opencontainers_labels[@]}"
    --file "${dockerfile}" "${package}/"
    --platform "${platform}"
    --tag "${full_tag}"
    --build-arg "DISTRO=${distro}"
    --build-arg "DISTRO_VERSION=${distro_version}"
    --build-arg "${distro_upper}_VERSION=${distro_version}"
    --build-arg "ARCH=${arch}"
    --build-arg "ENV=${env}"
  )
  if [[ "${distro_version}" == "${distro_latest}" ]]; then
    build_args+=(
      --tag "${repository}:${distro}-${arch}${env:+"-${env}"}"
      --tag "${repository}:${distro}-latest-${arch}${env:+"-${env}"}"
    )
  fi
  if [[ "${distro}" == "ubuntu" ]] && [[ "${distro_version}" == "${ubuntu_rolling}" ]]; then
    build_args+=(
      --tag "${repository}:${distro}-rolling-${arch}${env:+"-${env}"}"
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

env=''
for arch in "${host_dpkg_arch[@]}"; do
  log_dir="tmp/log/${package}/${distro}-${distro_version}"
  log_file="${log_dir}/build-docker-${arch}-${time}.log"
  mkdir -p -- "${log_dir}"
  case "${distro}" in
    ubuntu)
      base=apt
      distro_latest="${ubuntu_latest}"
      ;;
    debian)
      base=apt
      distro_latest="${debian_latest}-slim"
      distro_version="${distro_version%-slim}-slim"
      ;;
    *) bail "unrecognized distro '${distro}'" ;;
  esac
  build "$@" 2>&1 | tee -- "${log_file}"
  printf '%s\n' "info: build log saved at ${log_file}"
done

env=cross
for arch in "${cross_dpkg_arch[@]}"; do
  log_dir="tmp/log/${package}/${distro}-${distro_version}"
  log_file="${log_dir}/build-docker-${arch}-${time}.log"
  mkdir -p -- "${log_dir}"
  case "${distro}" in
    ubuntu)
      base=apt
      distro_latest="${ubuntu_latest}"
      ;;
    debian)
      base=apt
      distro_latest="${debian_latest}-slim"
      distro_version="${distro_version%-slim}-slim"
      ;;
    *) bail "unrecognized distro '${distro}'" ;;
  esac
  build "$@" 2>&1 | tee -- "${log_file}"
  printf '%s\n' "info: build log saved at ${log_file}"
done

x docker images "${repository}"

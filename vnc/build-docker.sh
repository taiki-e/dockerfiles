#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    ./vnc/build-docker.sh <DISTRO> [DOCKER_BUILD_OPTIONS]

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
platform=''
if [[ -n "${PLATFORM:-}" ]]; then
  platform="${PLATFORM}"
elif [[ -n "${CI:-}" ]]; then
  platform=linux/amd64,linux/arm64/v8
fi
desktop="${DESKTOP:-}"

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh

build() {
  local dockerfile="${package}/${base}.Dockerfile"
  local full_tag="${repository}:${distro}-${distro_version/-slim/}${desktop:+"-${desktop}"}"
  labels=(
    "${common_labels[@]}"
    "org.opencontainers.image.version=${distro}-${distro_version/-slim/}"
  )
  local build_args=(
    --file "${dockerfile}" "${package}/"
    --tag "${full_tag}"
    --build-arg "DISTRO=${distro}"
    --build-arg "DISTRO_VERSION=${distro_version}"
    --build-arg "${distro_upper}_VERSION=${distro_version}"
  )
  if [[ -n "${platform}" ]] && [[ "$*" != *"--platform"* ]]; then
    build_args+=(--platform "${platform}")
  fi
  if [[ -n "${desktop}" ]]; then
    build_args+=(
      --build-arg "DESKTOP=${desktop}"
    )
  fi
  if [[ "${distro_version}" == "${distro_latest}" ]]; then
    build_args+=(
      --tag "${repository}:${distro}${desktop:+"-${desktop}"}"
      --tag "${repository}:${distro}-latest${desktop:+"-${desktop}"}"
    )
  fi
  if [[ "${distro}" == "ubuntu" ]] && [[ "${distro_version}" == "${ubuntu_rolling}" ]]; then
    build_args+=(
      --tag "${repository}:${distro}-rolling${desktop:+"-${desktop}"}"
    )
  fi
  build_args+=("$@")

  docker_buildx_build "${full_tag}" "${build_args[@]}"
}

log_dir="tmp/log/${package}/${distro}-${distro_version}"
log_file="${log_dir}/build-docker${desktop:+"-${desktop}"}-${time}.log"
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
printf 'info: build log will be saved at %s\n' "${log_file}"
build "$@" 2>&1 | tee -- "${log_file}"

x docker images "${repository}"

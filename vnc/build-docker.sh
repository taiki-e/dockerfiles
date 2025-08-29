#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    ./vnc/build-docker.sh <DISTRO> [DOCKER_BUILD_OPTIONS]

x() {
  (
    set -x
    "$@"
  )
}
bail() {
  printf >&2 'error: %s\n' "$*"
  exit 1
}

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

export DOCKER_BUILDKIT=1
export BUILDKIT_STEP_LOG_MAX_SIZE=10485760

owner="${OWNER:-taiki-e}"
package=$(basename -- "$(cd -- "$(dirname -- "$0")" && pwd)")
repository="ghcr.io/${owner}/${package}"
platform="${PLATFORM:-"linux/amd64,linux/arm64/v8"}"
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

# See also tools/container-info.sh
ubuntu_latest=24.04
debian_latest=13

build() {
  local dockerfile="${package}/${base}.Dockerfile"
  local full_tag="${repository}:${distro}-${distro_version/-slim/}${DESKTOP:+"-${DESKTOP}"}"
  local build_args=(
    --file "${dockerfile}" "${package}/"
    --platform "${platform}"
    --tag "${full_tag}"
    --build-arg "DISTRO=${distro}"
    --build-arg "DISTRO_VERSION=${distro_version}"
    --build-arg "${distro_upper}_VERSION=${distro_version}"
  )
  if [[ -n "${DESKTOP:-}" ]]; then
    build_args+=(
      --build-arg "DESKTOP=${DESKTOP}"
    )
  fi
  if [[ "${distro_version}" == "${distro_latest}" ]]; then
    build_args+=(
      --tag "${repository}:${distro}${DESKTOP:+"-${DESKTOP}"}"
      --tag "${repository}:${distro}-latest${DESKTOP:+"-${DESKTOP}"}"
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

log_dir="tmp/log/${package}/${distro}-${distro_version}"
log_file="${log_dir}/build-docker${DESKTOP:+"-${DESKTOP}"}-${time}.log"
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

x docker images "${repository}"

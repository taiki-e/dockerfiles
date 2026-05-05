#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# USAGE:
#    ./build-base/build-docker.sh <DISTRO> [DOCKER_BUILD_OPTIONS]

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

# shellcheck source-path=SCRIPTDIR/..
. ./tools/build-docker-shared.sh

build() {
  local dockerfile="${package}/${base}.Dockerfile"
  local full_tag="${repository}:${distro}-${distro_version/-slim/}${mode:+"-${mode}"}"
  local build_args=(
    --file "${dockerfile}" "${package}/"
    --tag "${full_tag}"
    --build-arg "MODE=${mode}"
    --build-arg "DISTRO=${distro}"
    --build-arg "DISTRO_VERSION=${distro_version}"
    --build-arg "${distro_upper}_VERSION=${distro_version}"
  )
  if [[ -n "${platform}" ]] && [[ "$*" != *"--platform"* ]]; then
    build_args+=(--platform "${platform}")
  fi
  if [[ "${distro_version}" == "${distro_latest}" ]]; then
    build_args+=(
      --tag "${repository}:${distro}${mode:+"-${mode}"}"
      --tag "${repository}:${distro}-latest${mode:+"-${mode}"}"
    )
  fi
  if [[ "${distro}" == "ubuntu" ]] && [[ "${distro_version}" == "${ubuntu_rolling}" ]]; then
    build_args+=(
      --tag "${repository}:${distro}-rolling${mode:+"-${mode}"}"
    )
  fi
  build_args+=("$@")

  docker_buildx_build "${full_tag}" "${build_args[@]}"
}

for mode in slim ""; do
  log_dir="tmp/log/${package}/${distro}-${distro_version}"
  log_file="${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
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
    alpine)
      base=alpine
      distro_latest="${alpine_latest}"
      ;;
    *) bail "unrecognized distro '${distro}'" ;;
  esac
  printf 'info: build log will be saved at %s\n' "${log_file}"
  build "$@" 2>&1 | tee -- "${log_file}"
done

x docker images "${repository}"

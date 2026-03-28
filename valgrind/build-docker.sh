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
      case "${arch}" in
        mips64el)
          build_args+=(
            --build-arg "UBUNTU_VERSION=22.04"
          )
          ;;
      esac
      ;;
    *)
      target="${env}"
      case "${arch}" in
        amd64 | i386) platform=linux/amd64 ;;
        arm64 | armhf) platform=linux/arm64/v8 ;;
        ppc64el) platform=linux/ppc64le ;;
        riscv64) platform=linux/riscv64 ;;
        s390x) platform=linux/s390x ;;
        loong64)
          platform=linux/loong64
          # https://hub.docker.com/r/loongarch64/debian
          # TODO: use https://hub.docker.com/r/pkgforge/debian?
          build_args+=(
            --build-arg "DISTRO=loongarch64/debian"
            --build-arg "DISTRO_VERSION=sid@sha256:0356df4e494bbb86bb469377a00789a5b42bbf67d5ff649a3f9721b745cbef77"
          )
          # TODO:
          #  > [stage-2 4/4] RUN <<EOF (case "loong64" in...):
          # 0.110 valgrind: fatal error: unsupported CPU.
          # 0.110    Supported CPUs are:
          # 0.110    * x86 (practically any; Pentium-I or above), AMD Athlon or above)
          # 0.110    * AMD Athlon64/Opteron
          # 0.110    * ARM (armv7)
          # 0.110    * LoongArch (3A5000 and above)
          # 0.110    * MIPS (mips32 and above; mips64 and above)
          # 0.110    * PowerPC (most; ppc405 and above)
          # 0.110    * System z (64bit only - s390x; z990 and above)
          # 0.110
          # https://github.com/FreeFlyingSheep/valgrind-loongarch64/releases/tag/v3.21-GIT
          ;;
        mips64el)
          platform=linux/mips64le
          build_args+=(
            --build-arg "DISTRO=debian"
            --build-arg "DISTRO_VERSION=12"
            --build-arg "UBUNTU_VERSION=22.04"
          )
          # TODO:
          # 0.142 valgrind: fatal error: unsupported CPU.
          # 0.142    Supported CPUs are:
          # 0.142    * x86 (practically any; Pentium-I or above), AMD Athlon or above)
          # 0.142    * AMD Athlon64/Opteron
          # 0.142    * ARM (armv7)
          # 0.142    * MIPS (mips32 and above; mips64 and above)
          # 0.142    * PowerPC (most; ppc405 and above)
          # 0.142    * System z (64bit only - s390x; z990 and above)
          ;;
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
  case "${arch}" in
    ppc64el)
      build_args+=(
        --tag "${repository}:${valgrind_version}-ppc64le${target:+"-${target}"}"
      )
      if [[ "${valgrind_version}" == "${valgrind_latest}" ]]; then
        build_args+=(
          --tag "${repository}:ppc64le${target:+"-${target}"}"
        )
      fi
      ;;
    mips64el)
      build_args+=(
        --tag "${repository}:${valgrind_version}-mips64le${target:+"-${target}"}"
      )
      if [[ "${valgrind_version}" == "${valgrind_latest}" ]]; then
        build_args+=(
          --tag "${repository}:mips64le${target:+"-${target}"}"
        )
      fi
      ;;
  esac
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
  *) env=cross ;;
esac
build dist "$@" 2>&1 | tee -- "${log_file}"
build - "$@" 2>&1 | tee -- "${log_file}"
printf '%s\n' "info: build log saved at ${log_file}"

x docker images "${repository}"

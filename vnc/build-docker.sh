#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

# USAGE:
#    ./vnc/build-docker.sh <DISTRO> [DOCKER_BUILD_OPTIONS]

x() {
    local cmd="$1"
    shift
    (
        set -x
        "${cmd}" "$@"
    )
}

if [[ $# -lt 1 ]]; then
    cat <<EOF
USAGE:
    $0 <DISTRO> [DOCKER_BUILD_OPTIONS]
EOF
    exit 1
fi
distro="$1"
shift

export DOCKER_BUILDKIT=1
export BUILDKIT_STEP_LOG_MAX_SIZE=10485760

owner="${OWNER:-taiki-e}"
package=$(basename "$(dirname "$0")")
repository="ghcr.io/${owner}/${package}"
platform="${PLATFORM:-"linux/amd64,linux/arm64/v8"}"
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

distro_upper=$(tr '[:lower:]' '[:upper:]' <<<"${distro}")
# default_distro=ubuntu
# See also tools/container-info.sh
ubuntu_latest=22.04
ubuntu_versions=(20.04 22.04)

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
        # if [[ "${default_distro}" == "${distro}" ]]; then
        #     build_args+=(--tag "${repository}:latest")
        # fi
    fi
    build_args+=("$@")

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        x docker buildx build --provenance=false --push "${build_args[@]}" || (echo "info: build log saved at ${log_file}" && exit 1)
        x docker pull "${full_tag}"
        x docker history "${full_tag}"
    elif [[ "${platform}" == *","* ]]; then
        x docker buildx build --provenance=false "${build_args[@]}" || (echo "info: build log saved at ${log_file}" && exit 1)
    else
        x docker buildx build --provenance=false --load "${build_args[@]}" || (echo "info: build log saved at ${log_file}" && exit 1)
        x docker history "${full_tag}"
    fi
    x docker system df
}

case "${distro}" in
    ubuntu)
        base=apt
        distro_latest="${ubuntu_latest}"
        for distro_version in "${ubuntu_versions[@]}"; do
            log_dir="tmp/log/${package}/${distro}-${distro_version}"
            log_file="${log_dir}/build-docker${DESKTOP:+"-${DESKTOP}"}-${time}.log"
            mkdir -p "${log_dir}"
            build "$@" 2>&1 | tee "${log_file}"
            echo "info: build log saved at ${log_file}"
        done
        ;;
    *) echo >&2 "error: unrecognized distro '${distro}'" && exit 1 ;;
esac

x docker images "${repository}"

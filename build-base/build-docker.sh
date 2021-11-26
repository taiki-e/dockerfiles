#!/bin/bash

set -euxo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "$0")" && pwd)"/..

owner="${OWNER:-taiki-e}"
package="$(basename "$(dirname "$0")")"
platform=linux/amd64,linux/arm64/v8
base_tag="ghcr.io/${owner}/${package}"

distro="${DISTRO:?}"
distro_upper="$(tr '[:lower:]' '[:upper:]' <<<"${distro}")"
default_distro=ubuntu
# https://wiki.ubuntu.com/Releases
# https://hub.docker.com/_/ubuntu
ubuntu_latest=20.04
ubuntu_versions=(18.04 20.04)
# https://alpinelinux.org/releases
# https://hub.docker.com/_/alpine
alpine_latest=3.15
alpine_versions=(3.13 3.14 3.15)

export DOCKER_BUILDKIT=1

build() {
    local dockerfile="${package}/${distro}.Dockerfile"
    local full_tag="${base_tag}:${distro}-${distro_version}"
    local build_args=(
        --file "${dockerfile}" "${package}/"
        --platform "${platform}"
        --tag "${full_tag}"
        --build-arg "DISTRO=${distro}"
        --build-arg "${distro_upper}_VERSION=${distro_version}"
    )
    if [[ "${distro_version}" == "${distro_latest}" ]]; then
        build_args+=(
            --tag "${base_tag}:${distro}"
            --tag "${base_tag}:${distro}-latest"
        )
        if [[ "${default_distro}" == "${distro}" ]]; then
            build_args+=(
                --tag "${base_tag}:latest"
            )
        fi
    fi

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        docker buildx build --push "${build_args[@]}" "$@"
        docker pull "${full_tag}"
        docker history "${full_tag}"
    elif [[ "${platform}" == *","* ]]; then
        docker buildx build "${build_args[@]}" "$@"
    else
        docker buildx build --load "${build_args[@]}" "$@"
        docker history "${full_tag}"
    fi
}

time="$(date --utc '+%Y-%m-%d-%H-%M-%S')"
case "${distro}" in
    ubuntu)
        distro_latest="${ubuntu_latest}"
        for distro_version in "${ubuntu_versions[@]}"; do
            log_dir="tmp/log/${package}/${distro}-${distro_version}"
            mkdir -p "${log_dir}"
            build "${build_args[@]}" 2>&1 | tee "${log_dir}/build-docker-${time}.log"
        done
        ;;
    alpine)
        distro_latest="${alpine_latest}"
        for distro_version in "${alpine_versions[@]}"; do
            log_dir="tmp/log/${package}/${distro}-${distro_version}"
            mkdir -p "${log_dir}"
            build "${build_args[@]}" 2>&1 | tee "${log_dir}/build-docker-${time}.log"
        done
        ;;
    *) echo >&2 "unrecognized distro '${distro}'" && exit 1 ;;
esac

#!/bin/bash

set -euxo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "$0")" && pwd)"/..

owner="${OWNER:-taiki-e}"
package="$1"
platform=linux/amd64,linux/arm64/v8
base_tag="ghcr.io/${owner}/${package}"

# https://wiki.ubuntu.com/Releases
# https://hub.docker.com/_/ubuntu
ubuntu_latest=20.04
ubuntu_versions=(18.04 20.04)
# https://alpinelinux.org/releases
# https://hub.docker.com/_/alpine
alpine_latest=3.15
alpine_versions=(3.13 3.14 3.15)

case "${package}" in
    build-base) default_distro=ubuntu ;;
    downloader) default_distro=alpine ;;
    *) echo >&2 "unrecognized distro '${package}'" && exit 1 ;;
esac

export DOCKER_BUILDKIT=1

build() {
    local base="$1"
    shift
    local dockerfile="${package}/${base}.Dockerfile"
    local build_args=(
        --file "${dockerfile}" "${package}/"
        --platform "${platform}"
    )

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        docker buildx build --push "${build_args[@]}" "$@"
    elif [[ "${platform}" == *","* ]]; then
        docker buildx build "${build_args[@]}" "$@"
    else
        docker buildx build --load "${build_args[@]}" "$@"
    fi
}

mkdir -p tmp/log
for ubuntu_version in "${ubuntu_versions[@]}"; do
    build_args=(
        --build-arg "UBUNTU_VERSION=${ubuntu_version}"
        --tag "${base_tag}:ubuntu-${ubuntu_version}"
    )
    if [[ "${ubuntu_version}" == "${ubuntu_latest}" ]]; then
        build_args+=(
            --tag "${base_tag}:ubuntu"
            --tag "${base_tag}:ubuntu-latest"
        )
        if [[ "${default_distro}" == "ubuntu" ]]; then
            build_args+=(
                --tag "${base_tag}:latest"
            )
        fi
    fi
    build "ubuntu" "${build_args[@]}" 2>&1 | tee "tmp/log/build-docker.${package}.log"
done
for alpine_version in "${alpine_versions[@]}"; do
    build_args=(
        --build-arg "ALPINE_VERSION=${alpine_version}"
        --tag "${base_tag}:alpine-${alpine_version}"
    )
    if [[ "${alpine_version}" == "${alpine_latest}" ]]; then
        build_args+=(
            --tag "${base_tag}:alpine"
            --tag "${base_tag}:alpine-latest"
        )
        if [[ "${default_distro}" == "alpine" ]]; then
            build_args+=(
                --tag "${base_tag}:latest"
            )
        fi
    fi
    build "alpine" "${build_args[@]}" 2>&1 | tee "tmp/log/build-docker.${package}.log"
done

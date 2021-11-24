#!/bin/bash

set -euxo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "$0")" && pwd)"/..

export DOCKER_BUILDKIT=1

OWNER=${OWNER:-taiki-e}
PACKAGE="$(basename "$(dirname "$0")")"
PLATFORM=linux/amd64,linux/arm64/v8

build() {
    local base="$1"
    shift
    local dockerfile="${PACKAGE}/${base}.Dockerfile"
    local build_args=(
        --file "${dockerfile}" "${PACKAGE}/"
        --platform "${PLATFORM}"
    )

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        docker buildx build --push "${build_args[@]}" "$@"
    elif [[ "${PLATFORM}" == *","* ]]; then
        docker buildx build "${build_args[@]}" "$@"
    else
        docker buildx build --load "${build_args[@]}" "$@"
    fi
}

mkdir -p tmp/log
base_tag="ghcr.io/${OWNER}/${PACKAGE}"
ubuntu_latest=20.04
for ubuntu_version in 20.04 18.04; do
    build_args=(
        --build-arg "UBUNTU_VERSION=${ubuntu_version}"
        --tag "${base_tag}:ubuntu-${ubuntu_version}"
    )
    if [[ "${ubuntu_version}" == "${ubuntu_latest}" ]]; then
        build_args+=(
            --tag "${base_tag}:ubuntu"
            --tag "${base_tag}:ubuntu-latest"
            --tag "${base_tag}:latest"
        )
    fi
    build "ubuntu" "${build_args[@]}" 2>&1 | tee "tmp/log/build-docker.${PACKAGE}.log"
done
alpine_latest=3.14
for alpine_version in 3.14 3.13; do
    build_args=(
        --build-arg "ALPINE_VERSION=${alpine_version}"
        --tag "${base_tag}:alpine-${alpine_version}"
    )
    if [[ "${alpine_version}" == "${alpine_latest}" ]]; then
        build_args+=(
            --tag "${base_tag}:alpine"
            --tag "${base_tag}:alpine-latest"
        )
    fi
    build "alpine" "${build_args[@]}" 2>&1 | tee "tmp/log/build-docker.${PACKAGE}.log"
done

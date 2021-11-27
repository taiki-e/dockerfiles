#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "$0")" && pwd)"/..

if [[ $# -gt 0 ]]; then
    cat <<EOF
USAGE:
    $0
EOF
    exit 1
fi
set -x

export DOCKER_BUILDKIT=1

owner="${OWNER:-taiki-e}"
package="$(basename "$(dirname "$0")")"
platform=linux/amd64,linux/arm64/v8
base_tag="ghcr.io/${owner}/${package}"
time="$(date --utc '+%Y-%m-%d-%H-%M-%S')"

build() {
    local dockerfile="${package}/Dockerfile"
    local full_tag="${base_tag}:latest"
    local build_args=(
        --file "${dockerfile}" "${package}/"
        --platform "${platform}"
        --tag "${full_tag}"
    )

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

log_dir="tmp/log/${package}"
mkdir -p "${log_dir}"
build "${build_args[@]}" 2>&1 | tee "${log_dir}/build-docker-${time}.log"

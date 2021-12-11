#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "$0")" && pwd)"/..

if [[ $# -gt 1 ]]; then
    cat <<EOF
USAGE:
    $0 <PACKAGE>
EOF
    exit 1
fi
set -x
package="$1"

export DOCKER_BUILDKIT=1

owner="${OWNER:-taiki-e}"
registry="ghcr.io/${owner}"
tag_base="${registry}/${package}:"
platform="${PLATFORM:-"linux/amd64,linux/arm64/v8"}"
time="$(date --utc '+%Y-%m-%d-%H-%M-%S')"

build() {
    local dockerfile="${package}/Dockerfile"
    local full_tag="${tag_base}latest"
    local build_args=(
        --file "${dockerfile}" "${package}/"
        --platform "${platform}"
        --tag "${full_tag}"
    )

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        docker buildx build --push "${build_args[@]}"
        docker pull "${full_tag}"
        docker history "${full_tag}"
    elif [[ "${platform}" == *","* ]]; then
        docker buildx build "${build_args[@]}"
    else
        docker buildx build --load "${build_args[@]}"
        docker history "${full_tag}"
    fi
}

log_dir="tmp/log/${package}"
mkdir -p "${log_dir}"
build 2>&1 | tee "${log_dir}/build-docker-${time}.log"

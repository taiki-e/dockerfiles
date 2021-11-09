#!/bin/bash

set -euo pipefail
set -x
IFS=$'\n\t'

cd "$(cd "$(dirname "$0")" && pwd)"/..

export DOCKER_BUILDKIT=1

platform=linux/amd64,linux/arm64

build() {
    local name="${1:?}"
    shift
    echo "Building docker image for ${name}"

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        docker buildx build --push -t "ghcr.io/${OWNER}/${name}:latest" -f "${name}/Dockerfile" --platform "${platform}" . "$@"
    else
        docker buildx build -t "${name}" -f "${name}/Dockerfile" --platform "${platform}" . "$@"
    fi
}

mkdir -p tmp
if [[ -z "${1:-}" ]]; then
    for dockerfile in */Dockerfile; do
        build "${dockerfile%/Dockerfile}" 2>&1 | tee tmp/build-docker.log
    done
else
    build "$1/Dockerfile" "$1" 2>&1 | tee tmp/build-docker.log
fi

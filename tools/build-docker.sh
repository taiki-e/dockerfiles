#!/bin/bash

set -euo pipefail
set -x
IFS=$'\n\t'

cd "$(cd "$(dirname "$0")" && pwd)"/..

OWNER=taiki-e

export DOCKER_BUILDKIT=1

build() {
    local name="${1:?}"
    shift
    echo "Building docker image for ${name}"
    docker build -t "${name}" -f "${name}/Dockerfile" . "$@"

    if [[ -n "${CI:-}" ]]; then
        docker tag "${name}" "ghcr.io/${OWNER}/${name}:latest"
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

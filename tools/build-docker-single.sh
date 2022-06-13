#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

x() {
    local cmd="$1"
    shift
    (
        set -x
        "${cmd}" "$@"
    )
}

if [[ $# -gt 1 ]]; then
    cat <<EOF
USAGE:
    $0 <PACKAGE>
EOF
    exit 1
fi
package="$1"

export DOCKER_BUILDKIT=1
export BUILDKIT_STEP_LOG_MAX_SIZE=10485760

owner="${OWNER:-taiki-e}"
repository="ghcr.io/${owner}/${package}"
platform="${PLATFORM:-"linux/amd64,linux/arm64/v8"}"
time="$(date -u '+%Y-%m-%d-%H-%M-%S')"

build() {
    local dockerfile="${package}/Dockerfile"
    local tag="${repository}:latest"
    local build_args=(
        --file "${dockerfile}" "${package}/"
        --platform "${platform}"
        --tag "${tag}"
    )

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        x docker buildx build --push "${build_args[@]}" || (echo "info: build log saved at ${log_dir}/build-docker-${time}.log" && exit 1)
        x docker pull "${tag}"
        x docker history "${tag}"
    elif [[ "${platform}" == *","* ]]; then
        x docker buildx build "${build_args[@]}" || (echo "info: build log saved at ${log_dir}/build-docker-${time}.log" && exit 1)
    else
        x docker buildx build --load "${build_args[@]}" || (echo "info: build log saved at ${log_dir}/build-docker-${time}.log" && exit 1)
        x docker history "${tag}"
    fi
}

log_dir="tmp/log/${package}"
mkdir -p "${log_dir}"
build 2>&1 | tee "${log_dir}/build-docker-${time}.log"
echo "info: build log saved at ${log_dir}/build-docker-${time}.log"

x docker images "${repository}"

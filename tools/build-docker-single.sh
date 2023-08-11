#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

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
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

build() {
    local dockerfile="${package}/Dockerfile"
    local tag="${repository}:latest"
    local build_args=(
        --file "${dockerfile}" "${package}/"
        --platform "${platform}"
        --tag "${tag}"
    )

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        x docker buildx build --provenance=false --push "${build_args[@]}" || (echo "info: build log saved at ${log_file}" && exit 1)
        x docker pull "${tag}"
        x docker history "${tag}"
    elif [[ "${platform}" == *","* ]]; then
        x docker buildx build --provenance=false "${build_args[@]}" || (echo "info: build log saved at ${log_file}" && exit 1)
    else
        x docker buildx build --provenance=false --load "${build_args[@]}" || (echo "info: build log saved at ${log_file}" && exit 1)
        x docker history "${tag}"
    fi
    x docker system df
}

log_dir="tmp/log/${package}"
log_file="${log_dir}/build-docker-${time}.log"
mkdir -p "${log_dir}"
build 2>&1 | tee "${log_file}"
echo "info: build log saved at ${log_file}"

x docker images "${repository}"

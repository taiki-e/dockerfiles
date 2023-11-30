#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -eEuo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

# USAGE:
#    ./qemu-user/build-docker.sh

x() {
    local cmd="$1"
    shift
    (
        set -x
        "${cmd}" "$@"
    )
}

if [[ $# -gt 0 ]]; then
    cat <<EOF
USAGE:
    $0
EOF
    exit 1
fi

export DOCKER_BUILDKIT=1
export BUILDKIT_STEP_LOG_MAX_SIZE=10485760

owner="${OWNER:-taiki-e}"
package=$(basename "$(dirname "$0")")
repository="ghcr.io/${owner}/${package}"
platform="${PLATFORM:-"linux/amd64,linux/arm64/v8"}"
time=$(date -u '+%Y-%m-%d-%H-%M-%S')

# https://ftp.debian.org/debian/pool/main/q/qemu
# https://tracker.debian.org/pkg/qemu
latest=8.1
dpkg_versions=(
    8.2.0~rc1+ds-1
    8.1.3+ds-1
    7.2+dfsg-7+deb12u2
)

build() {
    local dockerfile="${package}/Dockerfile"
    local full_tag="${repository}:${version}"
    local build_args=(
        --file "${dockerfile}" "${package}/"
        --platform "${platform}"
        --tag "${full_tag}"
        --build-arg "QEMU_DPKG_VERSION=${dpkg_version}"
    )
    if [[ "${version}" == "${latest}" ]]; then
        build_args+=(
            --tag "${repository}:latest"
        )
    fi

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

for dpkg_version in "${dpkg_versions[@]}"; do
    if [[ "${dpkg_version}" =~ ^[1-9]\.[0-9][\.\+].+ ]]; then
        version=$(cut -c '-3' <<<"${dpkg_version}")
    elif [[ "${dpkg_version}" =~ ^[1-9][0-9]\.[0-9][\.\+].+ ]]; then
        version=$(cut -c '-4' <<<"${dpkg_version}")
    else
        echo "error: ${dpkg_version}"
        exit 1
    fi
    log_dir="tmp/log/${package}/${version}"
    log_file="${log_dir}/build-docker-${time}.log"
    mkdir -p "${log_dir}"
    build 2>&1 | tee "${log_file}"
    echo "info: build log saved at ${log_file}"
done

x docker images "${repository}"

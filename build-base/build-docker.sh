#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# USAGE:
#    ./build-base/build-docker.sh <DISTRO>

cd "$(cd "$(dirname "$0")" && pwd)"/..

if [[ $# -gt 1 ]]; then
    cat <<EOF
USAGE:
    $0 <DISTRO>
EOF
    exit 1
fi
set -x
distro="$1"

export DOCKER_BUILDKIT=1

owner="${OWNER:-taiki-e}"
package="$(basename "$(dirname "$0")")"
platform=linux/amd64,linux/arm64/v8
base_tag="ghcr.io/${owner}/${package}"
time="$(date --utc '+%Y-%m-%d-%H-%M-%S')"

distro_upper="$(tr '[:lower:]' '[:upper:]' <<<"${distro}")"
default_distro=ubuntu
# https://wiki.ubuntu.com/Releases
# https://hub.docker.com/_/ubuntu
ubuntu_latest=20.04
ubuntu_versions=(18.04 20.04)
# https://wiki.debian.org/DebianReleases
# https://hub.docker.com/_/debian
debian_latest=11-slim
debian_versions=(10-slim 11-slim)
# https://alpinelinux.org/releases
# https://hub.docker.com/_/alpine
alpine_latest=3.15
alpine_versions=(3.13 3.14 3.15)

build() {
    local dockerfile="${package}/${base}.Dockerfile"
    local full_tag="${base_tag}:${distro}-${distro_version/-slim/}${mode:+"-${mode}"}"
    local build_args=(
        --file "${dockerfile}" "${package}/"
        --platform "${platform}"
        --tag "${full_tag}"
        --build-arg "MODE=${mode}"
        --build-arg "DISTRO=${distro}"
        --build-arg "DISTRO_VERSION=${distro_version}"
        --build-arg "${distro_upper}_VERSION=${distro_version}"
    )
    if [[ "${distro_version}" == "${distro_latest}" ]]; then
        build_args+=(
            --tag "${base_tag}:${distro}${mode:+"-${mode}"}"
            --tag "${base_tag}:${distro}-latest${mode:+"-${mode}"}"
        )
        if [[ "${default_distro}" == "${distro}" ]]; then
            build_args+=(--tag "${base_tag}:${mode:-latest}")
        fi
    fi

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

for mode in slim ""; do
    case "${distro}" in
        ubuntu)
            base=apt
            distro_latest="${ubuntu_latest}"
            for distro_version in "${ubuntu_versions[@]}"; do
                log_dir="tmp/log/${package}/${distro}-${distro_version}"
                mkdir -p "${log_dir}"
                build 2>&1 | tee "${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
            done
            ;;
        debian)
            base=apt
            distro_latest="${debian_latest}"
            for distro_version in "${debian_versions[@]}"; do
                log_dir="tmp/log/${package}/${distro}-${distro_version}"
                mkdir -p "${log_dir}"
                build 2>&1 | tee "${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
            done
            ;;
        alpine)
            base=alpine
            distro_latest="${alpine_latest}"
            for distro_version in "${alpine_versions[@]}"; do
                log_dir="tmp/log/${package}/${distro}-${distro_version}"
                mkdir -p "${log_dir}"
                build 2>&1 | tee "${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
            done
            ;;
        *) echo >&2 "unrecognized distro '${distro}'" && exit 1 ;;
    esac
done

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: Error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

# USAGE:
#    ./build-base/build-docker.sh <DISTRO>

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
    $0 <DISTRO>
EOF
    exit 1
fi
distro="$1"

export DOCKER_BUILDKIT=1
export BUILDKIT_STEP_LOG_MAX_SIZE=10485760

owner="${OWNER:-taiki-e}"
package="$(basename "$(dirname "$0")")"
repository="ghcr.io/${owner}/${package}"
platform=linux/amd64,linux/arm64/v8
time="$(date -u '+%Y-%m-%d-%H-%M-%S')"

distro_upper="$(tr '[:lower:]' '[:upper:]' <<<"${distro}")"
default_distro=ubuntu
# https://wiki.ubuntu.com/Releases
# https://hub.docker.com/_/ubuntu
# https://endoflife.date/ubuntu
# | version        | EoL        | glibc |
# | -------------- | ---------- | ----- |
# | 22.04 (jammy)  | 2027-04-02 | 2.35  |
# | 20.04 (focal)  | 2025-04-02 | 2.31  |
# | 18.04 (bionic) | 2023-04-02 | 2.27  |
# | 16.04 (xenial) | 2021-04-02 | 2.23  |
ubuntu_latest=22.04
ubuntu_versions=(18.04 20.04 22.04 rolling)
# https://wiki.debian.org/DebianReleases
# https://hub.docker.com/_/debian
# https://endoflife.date/debian
# | version       | EoL        | glibc |
# | ------------- | ---------- | ----- |
# | 11 (bullseye) | 2026-08-15 | 2.31  |
# | 10 (buster)   | 2024-06-01 | 2.28  |
# | 9 (stretch)   | 2022-06-30 | 2.24  |
debian_latest=11
debian_versions=(10 11 sid)
# https://alpinelinux.org/releases
# https://hub.docker.com/_/alpine
# https://endoflife.date/alpine
# | version | EoL        | musl   |
# | ------- | ---------- | ------ |
# | 3.17    | 2024-11-22 | 1.2.3  |
# | 3.16    | 2024-05-23 | 1.2.3  |
# | 3.15    | 2023-11-01 | 1.2.2  |
# | 3.14    | 2023-05-01 | 1.2.2  |
# | 3.13    | 2022-11-01 | 1.2.2  |
# | 3.12    | 2022-05-01 | 1.1.24 |
alpine_latest=3.17
alpine_versions=(3.13 3.14 3.15 3.16 3.17 edge)

build() {
    local dockerfile="${package}/${base}.Dockerfile"
    local full_tag="${repository}:${distro}-${distro_version/-slim/}${mode:+"-${mode}"}"
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
            --tag "${repository}:${distro}${mode:+"-${mode}"}"
            --tag "${repository}:${distro}-latest${mode:+"-${mode}"}"
        )
        if [[ "${default_distro}" == "${distro}" ]]; then
            build_args+=(--tag "${repository}:${mode:-latest}")
        fi
    fi

    if [[ -n "${PUSH_TO_GHCR:-}" ]]; then
        x docker buildx build --provenance=false --push "${build_args[@]}" "$@" || (echo "info: build log saved at ${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log" && exit 1)
        x docker pull "${full_tag}"
        x docker history "${full_tag}"
    elif [[ "${platform}" == *","* ]]; then
        x docker buildx build --provenance=false "${build_args[@]}" "$@" || (echo "info: build log saved at ${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log" && exit 1)
    else
        x docker buildx build --provenance=false --load "${build_args[@]}" "$@" || (echo "info: build log saved at ${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log" && exit 1)
        x docker history "${full_tag}"
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
                case "${distro_version}" in
                    18.04) build --build-arg "LLVM_VERSION=13" 2>&1 | tee "${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log" ;;
                    *) build 2>&1 | tee "${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log" ;;
                esac
                echo "info: build log saved at ${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
            done
            ;;
        debian)
            base=apt
            distro_latest="${debian_latest}-slim"
            for distro_version in "${debian_versions[@]}"; do
                log_dir="tmp/log/${package}/${distro}-${distro_version}"
                mkdir -p "${log_dir}"
                distro_version="${distro_version}-slim"
                build 2>&1 | tee "${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
                echo "info: build log saved at ${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
            done
            ;;
        alpine)
            base=alpine
            distro_latest="${alpine_latest}"
            for distro_version in "${alpine_versions[@]}"; do
                log_dir="tmp/log/${package}/${distro}-${distro_version}"
                mkdir -p "${log_dir}"
                build 2>&1 | tee "${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
                echo "info: build log saved at ${log_dir}/build-docker${mode:+"-${mode}"}-${time}.log"
            done
            ;;
        *) echo >&2 "error: unrecognized distro '${distro}'" && exit 1 ;;
    esac
done

x docker images "${repository}"

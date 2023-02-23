#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: Error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

x() {
    local cmd="$1"
    shift
    (
        set -x
        "${cmd}" "$@"
    )
}

# https://wiki.ubuntu.com/Releases
# https://hub.docker.com/_/ubuntu
# https://endoflife.date/ubuntu
# | version        | EoL        | glibc |
# | -------------- | ---------- | ----- |
# | 22.04 (jammy)  | 2027-04-02 | 2.35  |
# | 20.04 (focal)  | 2025-04-02 | 2.31  |
# | 18.04 (bionic) | 2023-04-02 | 2.27  |
# | 16.04 (xenial) | 2021-04-02 | 2.23  |
# | 14.04 (trusty) | 2019-04-02 | 2.19  |
ubuntu_versions=(14.04 16.04 18.04 20.04 22.04 rolling)
# https://wiki.debian.org/DebianReleases
# https://hub.docker.com/_/debian
# https://endoflife.date/debian
# | version       | EoL        | glibc |
# | ------------- | ---------- | ----- |
# | 11 (bullseye) | 2026-08-15 | 2.31  |
# | 10 (buster)   | 2024-06-01 | 2.28  |
# | 9 (stretch)   | 2022-06-30 | 2.24  |
# | 8 (jessie)    | 2020-06-30 | 2.19  |
# | 7 (wheezy)    | 2018-05-31 | 2.13  |
debian_versions=(7 8 9 10 11 sid)
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
# | 3.11    | 2021-11-01 | 1.1.24 |
# | 3.10    | 2021-05-01 | 1.1.22 |
# | 3.9     | 2021-01-01 | 1.1.20 |
# | 3.8     | 2020-05-01 | 1.1.19 |
# | 3.7     | 2019-11-01 | 1.1.18 |
alpine_versions=(3.7 3.8 3.9 3.10 3.11 3.12 3.13 3.14 3.15 3.16 3.17 edge)
# https://docs.fedoraproject.org/en-US/releases
# https://hub.docker.com/_/fedora
# https://endoflife.date/fedora
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 37      | 2023-12-15 | 2.36  |
# | 36      | 2023-05-16 | 2.35  |
# | 35      | 2022-12-13 | 2.34  |
# | 34      | 2022-06-07 | 2.33  |
# | 33      | 2021-11-30 | 2.32  |
# | 32      | 2021-05-25 | 2.31  |
# | 31      | 2020-11-30 | 2.30  |
# | 30      | 2020-05-26 | 2.29  |
# | 29      | 2019-11-26 | 2.28  |
# | 28      | 2019-05-28 | 2.27  |
fedora_versions=(28 29 30 31 32 33 34 35 36 37 rawhide)
# https://hub.docker.com/_/centos
# https://endoflife.date/centos
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 8       | 2021-12-31 | 2.28  |
# | 7       | 2024-06-30 | 2.17  |
# | 6       | 2020-11-30 | 2.12  |
centos_versions=(6 7 8)
# https://hub.docker.com/_/rockylinux
# https://endoflife.date/rocky-linux
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 9       | 2032-05-31 | 2.34  |
# | 8       | 2029-05-31 | 2.28  |
rocky_versions=(8 9)

container_info() {
    local container="$1"
    echo "===== ${container} ====="

    # libc version
    case "${container}" in
        alpine*) docker run --rm --init "${container}" sh -c 'echo -n "musl: "; (ldd --version 2>&1 || true) | grep Version | sed "s/Version //"' ;;
        *) docker run --rm --init "${container}" sh -c 'echo -n "glibc: "; (ldd --version 2>&1 || true) | grep -E "GLIBC|GNU libc" | sed "s/.* //g"' ;;
    esac

    # /etc/os-release
    case "${container}" in
        *centos:6) ;; # /etc/os-release is unavailable in centos:6
        *) docker run --rm --init "${container}" sh -c 'cat /etc/os-release | grep -E "^(ID|ID_LIKE|VERSION_CODENAME)="' ;;
    esac

    # uname
    case "${container}" in
        *) docker run --rm --init "${container}" sh -c 'uname -a' ;;
    esac
}

for distro_version in "${ubuntu_versions[@]}"; do
    container_info ubuntu:"${distro_version}"
done
for distro_version in "${debian_versions[@]}"; do
    case "${distro_version}" in
        [0-8]) container_info amd64/debian:"${distro_version}" ;;
        *) container_info debian:"${distro_version}" ;;
    esac
done
for distro_version in "${fedora_versions[@]}"; do
    container_info fedora:"${distro_version}"
done
for distro_version in "${centos_versions[@]}"; do
    case "${distro_version}" in
        [0-6]) container_info amd64/centos:"${distro_version}" ;;
        *) container_info centos:"${distro_version}" ;;
    esac
done
for distro_version in "${rocky_versions[@]}"; do
    container_info rockylinux:"${distro_version}"
done
for distro_version in "${alpine_versions[@]}"; do
    container_info alpine:"${distro_version}"
done

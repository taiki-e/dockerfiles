#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# shellcheck disable=SC2016
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# https://wiki.debian.org/DebianReleases
# https://hub.docker.com/_/debian
# https://hub.docker.com/r/debian/eol
# https://endoflife.date/debian
# | version       | EoL        | glibc  |
# | ------------- | ---------- | ------ |
# | 13 (trixie)   | 2030-06-30 | 2.41   |
# | 12 (bookworm) | 2028-06-10 | 2.36   |
# | 11 (bullseye) | 2026-06-30 | 2.31   |
# | 10 (buster)   | 2024-06-30 | 2.28   |
# | 9 (stretch)   | 2022-07-01 | 2.24   |
# | 8 (jessie)    | 2020-06-30 | 2.19   |
# | 7 (wheezy)    | 2018-05-31 | 2.13   |
# | 6 (squeeze)   | 2016-02-29 | 2.11.3 |
# | 5 (lenny)     | 2012-02-06 | 2.7    |
# | 4 (etch)      | 2010-02-15 | 2.3.6  |
# | 3.1 (sarge)   | 2008-03-31 | 2.3.2  |
# | 3.0 (woody)   | 2006-06-30 | 2.2.5  |
# | 2.2 (potato)  | 2003-06-30 | 2.1.3  |
# | 2.1 (slink)   | 2000-10-30 | 2.0.7  |
# debian:6 docker image uses legacy image format (use debian/eol images instead).
# debian/eol:hamm-slim docker image (debian 2.0) is not available.
debian_versions=(2.1 2.2 3.1 4 5 6 7 8 9 10 11 12 13 testing sid)
debian_versions=()
# https://wiki.ubuntu.com/Releases
# https://hub.docker.com/_/ubuntu
# https://endoflife.date/ubuntu
# | version         | EoL        | ESM        | glibc |
# | --------------- | ---------- | ---------- | ----- |
# | 24.04 (noble)   | 2029-04-02 | 2036-04-25 | 2.39  |
# | 22.04 (jammy)   | 2027-04-02 | 2032-04-09 | 2.35  |
# | 20.04 (focal)   | 2025-04-02 | 2030-04-02 | 2.31  |
# | 18.04 (bionic)  | 2023-04-02 | 2028-04-01 | 2.27  |
# | 16.04 (xenial)  | 2021-04-02 | 2026-04-02 | 2.23  |
# | 14.04 (trusty)  | 2019-04-02 | 2024-04-02 | 2.19  |
# | 12.04 (precise) | 2017-04-28 | 2019-04-26 | 2.15  |
# ubuntu:10.04 docker image uses legacy image format.
ubuntu_versions=(12.04 14.04 16.04 18.04 20.04 22.04 24.04 rolling devel)
ubuntu_versions=()
# https://alpinelinux.org/releases
# https://hub.docker.com/_/alpine
# https://endoflife.date/alpine
# | version | EoL        | musl   |
# | ------- | ---------- | ------ |
# | 3.23    | 2027-11-01 | 1.2.5  |
# | 3.22    | 2027-05-01 | 1.2.5  |
# | 3.21    | 2026-11-01 | 1.2.5  |
# | 3.20    | 2026-04-01 | 1.2.5  |
# | 3.19    | 2025-11-01 | 1.2.4  |
# | 3.18    | 2025-05-09 | 1.2.4  |
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
# | 3.6     | ?          | 1.1.16 |
# | 3.5     | ?          | 1.1.15 |
# | 3.4     | ?          | 1.1.14 |
# | 3.3     | ?          | 1.1.12 |
# | 3.2     | ?          | 1.1.11 |
# | 3.1     | ?          | 1.1.5  |
# alpine:3.0 docker image is not available
alpine_versions=(3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 3.10 3.11 3.12 3.13 3.14 3.15 3.16 3.17 3.18 3.19 3.20 3.21 3.22 edge)
alpine_versions=()
# https://docs.fedoraproject.org/en-US/releases
# https://hub.docker.com/_/fedora
# https://endoflife.date/fedora
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 42      | 2026-05-13 | 2.41  |
# | 41      | 2025-11-19 | 2.40  |
# | 40      | 2025-05-13 | 2.39  |
# | 39      | 2024-12-07 | 2.38  |
# | 38      | 2024-05-18 | 2.37  |
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
# | 27      | ?          | 2.26  |
# | 26      | ?          | 2.25  |
# | 25      | ?          | 2.24  |
# | 24      | ?          | 2.23  |
# | 23      | ?          | 2.22  |
# | 22      | ?          | 2.21  |
# | 21      | ?          | 2.20  |
# | 20      | ?          | 2.18  |
# fedora:19 docker image is not available
fedora_versions=(20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 rawhide)
fedora_versions=()
# https://hub.docker.com/_/rockylinux
# https://endoflife.date/rocky-linux
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 10      | 2035-05-31 | 2.39  |
# | 9       | 2032-05-31 | 2.34  |
# | 8       | 2029-05-31 | 2.28  |
rocky_versions=(8 9 10)
rocky_versions=()
# https://hub.docker.com/_/almalinux
# https://endoflife.date/almalinux
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 10      | 2035-05-31 | 2.39  |
# | 9       | 2032-05-31 | 2.34  |
# | 8       | 2029-03-01 | 2.28  |
alma_versions=(8 9 10)
alma_versions=()
# https://hub.docker.com/_/centos
# https://endoflife.date/centos
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 8       | 2021-12-31 | 2.28  |
# | 7       | 2024-06-30 | 2.17  |
# | 6       | 2020-11-30 | 2.12  |
# | 5       | 2017-03-31 | 2.5   |
centos_versions=(5 6 7 8)
centos_versions=()
# https://hub.docker.com/r/opensuse/leap
# https://hub.docker.com/r/opensuse/tumbleweed
# https://endoflife.date/opensuse
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 15.6    | 2025-12-31 | 2.38  |
# | 15.5    | 2024-12-31 | 2.31  |
# | 15.4    | 2023-12-07 | 2.31  |
# | 15.3    | 2022-12-31 | 2.31  |
# | 15.2    | 2022-01-04 | 2.26  |
# | 15.1    | 2021-02-02 | 2.26  |
# | 15.0    | 2019-12-03 | 2.26  |
opensuse_versions=(15.0 15.1 15.2 15.3 15.4 15.5 15.6 tumbleweed)
opensuse_versions=()
# https://hub.docker.com/_/archlinux
arch_versions=(latest)
arch_versions=()

container_info() {
  local container="$1"
  shift
  printf '%s\n' "===== ${container} ====="

  # libc version
  case "${container}" in
    alpine*) docker run --rm --init "$@" "${container}" sh -c 'printf "musl: "; { ldd --version 2>&1 || true; } | grep -F Version | sed "s/Version //"' ;;
    debian*:slink* | debian*:potato*) docker run --rm --init "$@" "${container}" sh -c 'apt-cache show libc6 | grep -F Version' ;;
    *) docker run --rm --init "$@" "${container}" sh -c 'printf "glibc: "; { ldd --version 2>&1 || true; } | grep -E "GLIBC|GNU libc" | sed "s/.* //g"' ;;
  esac
  # /etc/os-release
  case "${container}" in
    centos:[0-6]) ;;
    debian*:slink* | debian*:potato* | debian*:woody* | debian*:sarge* | debian*:etch* | debian*:lenny* | debian*:squeeze*) ;; # [0-6]
    *) docker run --rm --init "$@" "${container}" sh -c 'cat -- /etc/os-release | grep -E "^(ID|ID_LIKE|VERSION_CODENAME)="' ;;
  esac
  case "${container}" in
    debian* | ubuntu*) docker run --rm --init "$@" "${container}" sh -c 'cat -- /etc/debian_version' ;;
    centos* | fedora* | rockylinux* | almalinux*) docker run --rm --init "$@" "${container}" sh -c 'cat -- /etc/redhat-release' ;;
  esac
  # uname
  docker run --rm --init "$@" "${container}" sh -c 'uname -a'
}

for distro_version in ${ubuntu_versions[@]+"${ubuntu_versions[@]}"}; do
  case "${distro_version}" in
    1[0-2].*) container_info ubuntu:"${distro_version}" --platform linux/amd64 ;;
    *) container_info ubuntu:"${distro_version}" ;;
  esac
done
for distro_version in ${debian_versions[@]+"${debian_versions[@]}"}; do
  case "${distro_version}" in
    2.1) container_info debian/eol:slink-slim --platform linux/amd64 ;;
    2.2) container_info debian/eol:potato-slim --platform linux/amd64 ;;
    3.0) container_info debian/eol:woody-slim --platform linux/amd64 ;;
    3.1) container_info debian/eol:sarge-slim --platform linux/amd64 ;;
    4) container_info debian/eol:etch-slim --platform linux/amd64 ;;
    5) container_info debian/eol:lenny-slim --platform linux/amd64 ;;
    6) container_info debian/eol:squeeze-slim --platform linux/amd64 ;;
    7) container_info debian/eol:wheezy-slim --platform linux/amd64 ;;
    8) container_info debian/eol:jessie-slim --platform linux/amd64 ;;
    *) container_info debian:"${distro_version}" ;;
  esac
done
for distro_version in ${fedora_versions[@]+"${fedora_versions[@]}"}; do
  case "${distro_version}" in
    2[0-5]) container_info fedora:"${distro_version}" --platform linux/amd64 ;;
    *) container_info fedora:"${distro_version}" ;;
  esac
done
for distro_version in ${centos_versions[@]+"${centos_versions[@]}"}; do
  case "${distro_version}" in
    [0-6]) container_info centos:"${distro_version}" --platform linux/amd64 ;;
    *) container_info centos:"${distro_version}" ;;
  esac
done
for distro_version in ${rocky_versions[@]+"${rocky_versions[@]}"}; do
  container_info rockylinux/rockylinux:"${distro_version}"
done
for distro_version in ${alma_versions[@]+"${alma_versions[@]}"}; do
  container_info almalinux:"${distro_version}"
done
for distro_version in ${alpine_versions[@]+"${alpine_versions[@]}"}; do
  case "${distro_version}" in
    3.[0-5]) container_info alpine:"${distro_version}" --platform linux/amd64 ;;
    *) container_info alpine:"${distro_version}" ;;
  esac
done
for distro_version in ${opensuse_versions[@]+"${opensuse_versions[@]}"}; do
  case "${distro_version}" in
    tumbleweed) container_info opensuse/tumbleweed ;;
    *) container_info opensuse/leap:"${distro_version}" ;;
  esac
done
for distro_version in ${arch_versions[@]+"${arch_versions[@]}"}; do
  container_info archlinux:"${distro_version}" --platform linux/amd64
done

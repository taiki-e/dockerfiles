#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# shellcheck disable=SC2016
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

# ------------------------------------------------------------------------------
# https://hub.docker.com/_/debian
# https://hub.docker.com/r/debian/eol
# https://www.debian.org/releases/
# | version       | EoL        | End of LTS | End of ELTS | glibc  |
# | ------------- | ---------- | ---------- | ----------- | ------ |
# | 13 (trixie)   | 2028-08-09 | 2030-06-30 | 2035-06-30  | 2.41   |
# | 12 (bookworm) | 2026-06-10 | 2028-06-30 | 2033-06-30  | 2.36   |
# | 11 (bullseye) | 2024-08-14 | 2026-08-31 | 2031-06-30  | 2.31   |
# | 10 (buster)   | 2022-09-10 | 2024-06-30 | 2029-06-30  | 2.28   |
# | 9 (stretch)   | 2020-07-18 | 2022-07-01 | 2027-06-30  | 2.24   |
# | 8 (jessie)    | 2018-06-17 | 2020-06-30 | 2025-06-30  | 2.19   |
# | 7 (wheezy)    | 2016-04-25 | 2018-05-31 | ~2020-06-30 | 2.13   |
# | 6 (squeeze)   | 2014-05-31 | 2016-02-29 |             | 2.11.3 |
# | 5 (lenny)     | 2012-02-06 |            |             | 2.7    |
# | 4 (etch)      | 2010-02-15 |            |             | 2.3.6  |
# | 3.1 (sarge)   | 2008-03-31 |            |             | 2.3.2  |
# | 3.0 (woody)   | 2006-06-30 |            |             | 2.2.5  |
# | 2.2 (potato)  | 2003-06-30 |            |             | 2.1.3  |
# | 2.1 (slink)   | 2000-09-30 | 2000-10-30 |             | 2.0.7  |
# | 2.0 (hamm)    | ?          |            |             | ?      |
# | 1.3 (bo)      | ?          |            |             | ?      |
# | 1.2 (rex)     | ?          |            |             | ?      |
# | 1.1 (buzz)    | ?          |            |             | ?      |
# debian:6 image uses legacy image format (use debian/eol images instead).
# debian/eol:hamm-slim (2.0) image is not available.
debian_versions=(2.1 2.2 3.1 4 5 6 7 8 9 10 11 12 13 testing unstable)
debian_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/_/ubuntu
# https://documentation.ubuntu.com/project/release-team/list-of-releases/
# | version          | EoL        | End of ESM | End of Legacy | glibc |
# | ---------------- | ---------- | ---------- | ------------- | ----- |
# | 26.04 (resolute) | 2031-05-?  | 2036-04    | 2041-04       | 2.43  |
# | 24.04 (noble)    | 2029-06-?  | 2034-04    | 2039-04       | 2.39  |
# | 22.04 (jammy)    | 2027-06-?  | 2032-04    | 2037-04       | 2.35  |
# | 20.04 (focal)    | 2025-05-31 | 2030-04    | 2035-04       | 2.31  |
# | 18.04 (bionic)   | 2023-05-31 | 2028-04    | 2033-04       | 2.27  |
# | 16.04 (xenial)   | 2021-04-?  | 2026-04    | 2031-04       | 2.23  |
# | 14.04 (trusty)   | 2019-04-25 | 2024-04    | 2029-04       | 2.19  |
# | 12.04 (precise)  | 2017-04-28 | 2019-04    |               | 2.15  |
# | 10.04 (lucid)    | 2015-04-30 |            |               | ?     |
# | 8.04 (lardy)     | 2013-05-09 |            |               | ?     |
# | 6.06 (dapper)    | 2011-06-01 |            |               | ?     |
# ubuntu:10.04 image uses legacy image format.
ubuntu_versions=(12.04 14.04 16.04 18.04 20.04 22.04 24.04 26.04 rolling devel)
ubuntu_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/_/fedora
# https://docs.fedoraproject.org/en-US/releases/eol
# https://fedorapeople.org/groups/schedule/
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 44      | 2027-06-02 | 2.43  |
# | 43      | 2026-12-09 | 2.42  |
# | 42      | 2026-05-27 | 2.41  |
# | 41      | 2025-12-15 | 2.40  |
# | 40      | 2025-05-13 | 2.39  |
# | 39      | 2024-11-26 | 2.38  |
# | 38      | 2024-05-21 | 2.37  |
# | 37      | 2023-12-05 | 2.36  |
# | 36      | 2023-05-16 | 2.35  |
# | 35      | 2022-12-13 | 2.34  |
# | 34      | 2022-06-07 | 2.33  |
# | 33      | 2021-11-30 | 2.32  |
# | 32      | 2021-05-25 | 2.31  |
# | 31      | 2020-11-24 | 2.30  |
# | 30      | 2020-05-26 | 2.29  |
# | 29      | 2019-11-26 | 2.28  |
# | 28      | 2019-05-28 | 2.27  |
# | 27      | 2018-11-30 | 2.26  |
# | 26      | 2018-05-29 | 2.25  |
# | 25      | 2017-12-12 | 2.24  |
# | 24      | 2017-08-08 | 2.23  |
# | 23      | 2016-12-20 | 2.22  |
# | 22      | 2016-07-19 | 2.21  |
# | 21      | 2015-12-01 | 2.20  |
# | 20      | 2015-06-23 | 2.18  |
# | 19      | 2015-01-06 | ?     |
# | 18      | 2014-01-14 | ?     |
# | 17      | 2013-07-30 | ?     |
# | 16      | 2013-02-12 | ?     |
# | 15      | 2012-06-26 | ?     |
# | 14      | 2011-12-09 | ?     |
# | 13      | 2011-06-24 | ?     |
# | 12      | 2010-12-02 | ?     |
# | 11      | 2010-06-25 | ?     |
# | 10      | 2009-12-17 | ?     |
# | 9       | 2009-07-10 | ?     |
# | 8       | 2009-01-07 | ?     |
# | 7       | 2008-06-13 | ?     |
# | 6       | 2007-12-07 | ?     |
# | 5       | 2007-07-02 | ?     |
# | 4       | 2006-08-07 | ?     |
# | 3       | 2006-01-16 | ?     |
# | 2       | 2005-04-11 | ?     |
# | 1       | 2004-09-20 | ?     |
# fedora:19 image is not available.
fedora_versions=(20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 rawhide)
fedora_versions=()
# ------------------------------------------------------------------------------
# https://endoflife.date/rhel
# | version | EoL        | End of ELS | glibc |
# | ------- | ---------- | ---------- | ----- |
# | 10      | 2035-05-31 | 2038-05-31 | 2.39  |
# | 9       | 2032-05-31 | 2035-05-31 | 2.34  |
# | 8       | 2029-05-31 | 2032-05-31 | 2.28  |
# | 7       | 2024-06-30 | 2029-05-31 | 2.17  |
# | 6       | 2020-11-30 | 2024-06-30 | 2.12  |
# | 5       | 2017-03-31 | 2020-11-30 | 2.5   |
# | 4       | 2012-02-29 | 2017-03-31 | ?     |
ubi_versions=(8 9 10)
ubi_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/_/centos
# https://endoflife.date/centos
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 8       | 2021-12-31 | 2.28  |
# | 7       | 2024-06-30 | 2.17  |
# | 6       | 2020-11-30 | 2.12  |
# | 5       | 2017-03-31 | 2.5   |
# centos:4 image is not available
centos_versions=(5 6 7 8)
centos_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/_/almalinux
# https://endoflife.date/almalinux
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 10      | 2035-05-31 | 2.39  |
# | 9       | 2032-05-31 | 2.34  |
# | 8       | 2029-03-01 | 2.28  |
alma_versions=(8 9 10)
alma_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/_/rockylinux
# https://endoflife.date/rocky-linux
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 10      | 2035-05-31 | 2.39  |
# | 9       | 2032-05-31 | 2.34  |
# | 8       | 2029-05-31 | 2.28  |
rocky_versions=(8 9 10)
rocky_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/_/oraclelinux
# https://www.oracle.com/a/ocom/docs/elsp-lifetime-069338.pdf
# | version | EoL        | End of Extended Support | glibc |
# | ------- | ---------- | ----------------------- | ----- |
# | 10      | 2035-06-30 | 2038-06-30              | 2.39  |
# | 9       | 2032-06-30 | 2035-06-30              | 2.34  |
# | 8       | 2029-07-31 | 2032-07-31              | 2.28  |
# | 7       | 2024-12-31 | 2029-06-30              | 2.17  |
# | 6       | 2021-03-31 | 2024-12-31              | 2.12  |
# | 5       | 2017-06-30 | 2020-11-30              | 2.5   |
# | 4       | 2013-02-28 |                         | ?     |
# | 3       | 2011-10-31 |                         | ?     |
# oraclelinux:4 image is not available
oracle_versions=(5 6 7 8 9 10)
oracle_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/_/amazonlinux
# https://endoflife.date/amazon-linux
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 2023    | 2029-06-30 | 2.34  |
# | 2       | 2026-06-30 | 2.26  |
# | 1 (AMI) | 2023-12-31 | 2.17  |
amazon_versions=(1 2 2023)
amazon_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/r/opensuse/leap
# https://hub.docker.com/r/opensuse/tumbleweed
# https://hub.docker.com/r/opensuse/archive
# https://endoflife.date/opensuse
# | version | EoL        | glibc |
# | ------- | ---------- | ----- |
# | 16.0    | 2027-10-31 | 2.40  |
# | 15.6    | 2026-04-30 | 2.38  |
# | 15.5    | 2024-12-31 | 2.31  |
# | 15.4    | 2023-12-07 | 2.31  |
# | 15.3    | 2022-12-31 | 2.31  |
# | 15.2    | 2022-01-04 | 2.26  |
# | 15.1    | 2021-02-02 | 2.26  |
# | 15.0    | 2019-12-03 | 2.26  |
# | 42.3    | 2019-07-01 | 2.?  |
# | 42.2    | 2018-01-26 | 2.?  |
# | 42.1    | 2017-05-17 | 2.19  |
# | 13.2    | 2017-01-17 | 2.19  |
# | 13.1    | 2016-02-03 | 2.?  |
# opensuse/leap:42.3 image is not available (use opensuse/archive images instead).
# opensuse/archive:13.1 image uses legacy image format.
opensuse_versions=(13.2 42.1 42.2 42.3 15.0 15.1 15.2 15.3 15.4 15.5 15.6 16.0 tumbleweed)
opensuse_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/_/alpine
# https://alpinelinux.org/releases
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
# | 3.9     | 2020-11-01 | 1.1.20 |
# | 3.8     | 2020-05-01 | 1.1.19 |
# | 3.7     | 2019-11-01 | 1.1.18 |
# | 3.6     | 2019-05-01 | 1.1.16 |
# | 3.5     | 2018-11-01 | 1.1.15 |
# | 3.4     | 2018-05-01 | 1.1.14 |
# | 3.3     | 2017-11-01 | 1.1.12 |
# | 3.2     | 2017-05-01 | 1.1.11 |
# | 3.1     | 2016-11-01 | 1.1.5  |
# | 3.0     | 2016-05-01 | ?      |
# | 2.7     | 2015-11-01 | uClibc |
# | 2.6     | 2015-05-01 | uClibc |
# | 2.5     | 2014-11-01 | uClibc |
# | 2.4     | 2014-05-01 | uClibc |
# | 2.3     | 2013-11-01 | uClibc |
# | 2.2     | 2013-05-01 | uClibc |
# | 2.1     | 2012-11-01 | uClibc |
# alpine:3.0 image is not available
alpine_versions=(3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 3.10 3.11 3.12 3.13 3.14 3.15 3.16 3.17 3.18 3.19 3.20 3.21 3.22 3.23 edge)
alpine_versions=()
# ------------------------------------------------------------------------------
# https://hub.docker.com/r/openwrt/rootfs
# https://openwrt.org/about/history
# https://endoflife.date/openwrt
# | version | EoL        | musl   |
# | ------- | ---------- | ------ |
# | 25.12   | ?          | 1.2.5  |
# | 24.10   | 2026-09-05 | 1.2.5  |
# | 23.05   | 2025-08-16 | 1.2.4  |
# | 22.03   | 2024-04-11 | ?      |
# | 21.02   | 2023-04-30 | ?      |
# | 19.07   | 2022-04-30 | ?      |
# | 18.06   | 2021-07-01 | 1.1.19 |
# | 17.01   | 2019-02-01 | ?      |
# | 15.05   | ?          | uClibc |
# openwrt/rootfs:x86-64-17.01.* image is not available

container_info() {
  local container="$1"
  shift
  printf '===== %s =====\n' "${container}"

  # libc version
  case "${container}" in
    alpine*) docker run --rm --init "$@" "${container}" sh -c 'printf "musl: "; { ldd --version 2>&1 || true; } | grep -F Version | sed "s/Version //"' ;;
    debian*:slink* | debian*:potato*) docker run --rm --init "$@" "${container}" sh -c 'apt-cache show libc6 | grep -F Version' ;;
    *) docker run --rm --init "$@" "${container}" sh -c 'printf "glibc: "; { ldd --version 2>&1 || true; } | grep -E "GLIBC|GNU libc" | sed "s/.* //g"' ;;
  esac
  # /etc/os-release
  case "${container}" in
    centos:[0-6] | oraclelinux:[0-6]) ;;
    debian*:slink* | debian*:potato* | debian*:woody* | debian*:sarge* | debian*:etch* | debian*:lenny* | debian*:squeeze*) ;; # [0-6]
    *) docker run --rm --init "$@" "${container}" sh -c 'cat -- /etc/os-release | grep -E "^(ID|ID_LIKE|VERSION_CODENAME)="' ;;
  esac
  case "${container}" in
    debian* | ubuntu*) docker run --rm --init "$@" "${container}" sh -c 'cat -- /etc/debian_version' ;;
    fedora* | redhat/ubi* | centos* | almalinux* | rockylinux* | oraclelinux*) docker run --rm --init "$@" "${container}" sh -c 'cat -- /etc/redhat-release' ;;
  esac
  # uname
  docker run --rm --init "$@" "${container}" sh -c 'uname -a'
}

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
for distro_version in ${ubuntu_versions[@]+"${ubuntu_versions[@]}"}; do
  case "${distro_version}" in
    1[0-2].*) container_info ubuntu:"${distro_version}" --platform linux/amd64 ;;
    *) container_info ubuntu:"${distro_version}" ;;
  esac
done
for distro_version in ${fedora_versions[@]+"${fedora_versions[@]}"}; do
  case "${distro_version}" in
    2[0-5]) container_info fedora:"${distro_version}" --platform linux/amd64 ;;
    *) container_info fedora:"${distro_version}" ;;
  esac
done
for distro_version in ${ubi_versions[@]+"${ubi_versions[@]}"}; do
  container_info redhat/ubi"${distro_version}":latest
done
for distro_version in ${centos_versions[@]+"${centos_versions[@]}"}; do
  case "${distro_version}" in
    [0-6]) container_info centos:"${distro_version}" --platform linux/amd64 ;;
    *) container_info centos:"${distro_version}" ;;
  esac
done
for distro_version in ${alma_versions[@]+"${alma_versions[@]}"}; do
  container_info almalinux:"${distro_version}"
done
for distro_version in ${rocky_versions[@]+"${rocky_versions[@]}"}; do
  container_info rockylinux/rockylinux:"${distro_version}"
done
for distro_version in ${oracle_versions[@]+"${oracle_versions[@]}"}; do
  case "${distro_version}" in
    [0-6]) container_info oraclelinux:"${distro_version}" --platform linux/amd64 ;;
    *) container_info oraclelinux:"${distro_version}" ;;
  esac
done
for distro_version in ${amazon_versions[@]+"${amazon_versions[@]}"}; do
  case "${distro_version}" in
    [1-2]) container_info amazonlinux:"${distro_version}" --platform linux/amd64 ;;
    *) container_info amazonlinux:"${distro_version}" ;;
  esac
done
for distro_version in ${opensuse_versions[@]+"${opensuse_versions[@]}"}; do
  case "${distro_version}" in
    tumbleweed) container_info opensuse/tumbleweed ;;
    13.* | 42.[1-2]) container_info opensuse/archive:"${distro_version}" --platform linux/amd64 ;;
    42.*) container_info opensuse/archive:"${distro_version}" ;;
    *) container_info opensuse/leap:"${distro_version}" ;;
  esac
done
for distro_version in ${alpine_versions[@]+"${alpine_versions[@]}"}; do
  case "${distro_version}" in
    3.[0-5]) container_info alpine:"${distro_version}" --platform linux/amd64 ;;
    *) container_info alpine:"${distro_version}" ;;
  esac
done
# TODO: openwrt

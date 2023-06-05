#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

# USAGE:
#    ./downloader/build-docker.sh

if [[ $# -gt 0 ]]; then
    cat <<EOF
USAGE:
    $0
EOF
    exit 1
fi

package="$(basename "$(dirname "$0")")"
./tools/build-docker-single.sh "${package}" "$@"

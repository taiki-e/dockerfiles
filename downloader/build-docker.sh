#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# USAGE:
#    ./downloader/build-docker.sh

cd "$(cd "$(dirname "$0")" && pwd)"/..

if [[ $# -gt 0 ]]; then
    cat <<EOF
USAGE:
    $0
EOF
    exit 1
fi
set -x

package="$(basename "$(dirname "$0")")"
./tools/build-docker-single.sh "${package}" "$@"

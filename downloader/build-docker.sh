#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

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

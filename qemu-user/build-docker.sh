#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

package="$(basename "$(dirname "$0")")"
"$(cd "$(dirname "$0")" && pwd)"/../tools/build-docker-single.sh "${package}" "$@"

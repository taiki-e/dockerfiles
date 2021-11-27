#!/bin/bash
# shellcheck disable=SC2046
# shellcheck disable=SC2230 # https://github.com/koalaman/shellcheck/issues/1162
set -euo pipefail
IFS=$'\n\t'

# Usage:
#    ./tools/tidy.sh
#
# NOTE: This script requires the following tools:
# - shfmt
# - prettier
# - shellcheck

if [[ "${1:-}" == "-v" ]]; then
    set -x
fi

cd "$(cd "$(dirname "$0")" && pwd)"/..

prettier=prettier
if which npm &>/dev/null && which "$(npm bin)/prettier" &>/dev/null; then
    prettier="$(npm bin)/prettier"
fi

if [[ -z "${CI:-}" ]]; then
    if which shfmt &>/dev/null; then
        shfmt -l -w $(git ls-files '*.sh')
    else
        echo >&2 "WARNING: 'shfmt' is not installed"
    fi
    if which "${prettier}" &>/dev/null; then
        "${prettier}" -l -w $(git ls-files '*.yml')
    else
        echo >&2 "WARNING: 'prettier' is not installed"
    fi
    if which shellcheck &>/dev/null; then
        shellcheck $(git ls-files '*.sh')
        # SC2154 doesn't seem to work on dockerfile.
        shellcheck -e SC2148,SC2154 $(git ls-files '*Dockerfile')
    else
        echo >&2 "WARNING: 'shellcheck' is not installed"
    fi
else
    shfmt -d $(git ls-files '*.sh')
    "${prettier}" -c $(git ls-files '*.yml')
    shellcheck $(git ls-files '*.sh')
    # SC2154 doesn't seem to work on dockerfile.
    shellcheck -e SC2148,SC2154 $(git ls-files '*Dockerfile')
fi

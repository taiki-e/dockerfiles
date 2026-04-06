#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
trap -- 'printf >&2 "%s\n" "${0##*/}: trapped SIGINT"; exit 1' SIGINT

# shellcheck source-path=SCRIPTDIR
. "$(dirname -- "$0")"/shared.sh

if [[ $# -gt 0 ]]; then
  cat <<EOF
USAGE:
    $0
EOF
  exit 1
fi

# GitHub actions/workflows
if [[ -n "${TIDY_COLOR_ALWAYS}" ]]; then
  zizmor() { command zizmor --color=always "$@"; }
fi
info "checking GitHub actions/workflows"
workflows=()
actions=()
if [[ -d .github/workflows ]]; then
  for p in .github/workflows/*.yml; do
    workflows+=("${p}")
  done
fi
if [[ -n "$(ls_files '*action.yml')" ]]; then
  for p in $(ls_files '*action.yml'); do
    if [[ "${p##*/}" == 'action.yml' ]]; then
      actions+=("${p}")
    fi
  done
fi
zizmor_targets=(${workflows[@]+"${workflows[@]}"} ${actions[@]+"${actions[@]}"})
if [[ -e .github/dependabot.yml ]]; then
  zizmor_targets+=(.github/dependabot.yml)
fi
if [[ ${#zizmor_targets[@]} -gt 0 ]]; then
  check_config .github/zizmor.yml
  # Do not use `zizmor .` here because it also attempts to check submodules.
  IFS=' '
  info "running \`zizmor -q --strict-collection --persona=auditor ${zizmor_targets[*]}\`"
  IFS=$'\n\t'
  zizmor -q --strict-collection --persona=auditor "${zizmor_targets[@]}"
  printf '\n'
else
  check_unused "GitHub actions/workflows" '*zizmor.yml'
fi

if [[ -n "${should_fail:-}" ]]; then
  exit 1
fi

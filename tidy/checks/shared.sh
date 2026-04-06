#!/bin/false
# SPDX-License-Identifier: Apache-2.0 OR MIT
# shellcheck shell=bash # not executable

error() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::error::%s\n' "$*"
  else
    printf >&2 'error: %s\n' "$*"
  fi
  should_fail=1
}
warn() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::warning::%s\n' "$*"
  else
    printf >&2 'warning: %s\n' "$*"
  fi
}
info() {
  printf >&2 'info: %s\n' "$*"
}
print_fenced() {
  printf '=======================================\n'
  printf '%s' "$*"
  printf '=======================================\n\n'
}
check_diff() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    if ! git -c color.ui=always --no-pager diff --exit-code "$@"; then
      should_fail=1
    fi
  elif [[ -n "${CI:-}" ]]; then
    if ! git --no-pager diff --exit-code "$@"; then
      should_fail=1
    fi
  else
    local res
    res=$(git --no-pager diff --name-only "$@")
    if [[ -n "${res}" ]]; then
      warn "please commit changes made by formatter/generator if exists on the following files"
      print_fenced "${res}"$'\n'
      should_fail=1
    fi
  fi
}
check_config() {
  if [[ ! -e "$1" ]]; then
    error "could not found $1 in the repository root${2:-}"
  fi
}
check_unused() {
  local kind="$1"
  shift
  local res
  res=$(ls_files "$@")
  if [[ -n "${res}" ]]; then
    error "the following files are unused because there is no ${kind}; consider removing them"
    print_fenced "${res}"$'\n'
  fi
}
check_alt() {
  local recommended=$1
  local not_recommended=$2
  if [[ -n "$3" ]]; then
    error "please use ${recommended} instead of ${not_recommended} for consistency"
    print_fenced "$3"$'\n'
  fi
}
check_hidden() {
  for file in "$@"; do
    check_alt ".${file}" "${file}" "$(LC_ALL=C comm -23 <(ls_files "*${file}") <(ls_files "*.${file}"))"
  done
}
sed_rhs_escape() {
  sed -E 's/\\/\\\\/g; s/\&/\\\&/g; s/\//\\\//g' <<<"$1"
}

# shellcheck disable=SC2034
should_fail=''

# - `find` lists symlinks. `! ( -name <dir> -prune )` means recursively ignore <dir>. `cut` removes the leading `./`.
#   This can be replaced with `fd -H -t l`.
# - `git submodule status` lists submodules. The first `cut` removes the first character indicates status ( |+|-).
# - `git ls-files --deleted` lists removed files.
find_prune=(\! \( -name .git -prune \))
while IFS= read -r; do
  find_prune+=(\! \( -name "${REPLY}" -prune \))
done < <(sed -E 's/#.*//g; s/^[ \t]+//g; s/\/[ \t]+$//g; /^$/d' .gitignore)
exclude_from_ls_files=()
while IFS=$'\n' read -r; do
  exclude_from_ls_files+=("${REPLY}")
done < <({
  find . "${find_prune[@]}" -type l | cut -c3-
  git submodule status | cut -c2- | cut -d' ' -f2
  git ls-files --deleted
} | LC_ALL=C sort -u)
exclude_from_ls_files_no_symlink=()
while IFS=$'\n' read -r; do
  exclude_from_ls_files_no_symlink+=("${REPLY}")
done < <({
  git submodule status | cut -c2- | cut -d' ' -f2
  git ls-files --deleted
} | LC_ALL=C sort -u)
ls_files() {
  if [[ "${1:-}" == '--include-symlink' ]]; then
    shift
    LC_ALL=C comm -23 <(git ls-files "$@" | LC_ALL=C sort) <(printf '%s\n' ${exclude_from_ls_files_no_symlink[@]+"${exclude_from_ls_files_no_symlink[@]}"})
  else
    LC_ALL=C comm -23 <(git ls-files "$@" | LC_ALL=C sort) <(printf '%s\n' ${exclude_from_ls_files[@]+"${exclude_from_ls_files[@]}"})
  fi
}

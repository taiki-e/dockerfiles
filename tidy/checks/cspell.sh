#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
trap -- 'printf >&2 "%s\n" "${0##*/}: trapped SIGINT"; exit 1' SIGINT

retry() {
  for i in {1..10}; do
    if "$@"; then
      return 0
    else
      sleep "${i}"
    fi
  done
  "$@"
}
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

should_fail=''
if [[ $# -gt 0 ]]; then
  cat <<EOF
USAGE:
    $0
EOF
  exit 1
fi

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

# Spell check (if config exists)
if [[ -n "${TIDY_COLOR_ALWAYS}" ]]; then
  cspell() { command cspell --color "$@"; }
fi
if [[ -f .cspell.json ]]; then
  info "spell checking"
  project_dictionary=.github/.cspell/project-dictionary.txt
  has_rust=''
  if [[ -n "$(ls_files '*Cargo.toml')" ]]; then
    has_rust=1
    dependencies=''
    for manifest_path in $(ls_files '*Cargo.toml'); do
      if [[ "${manifest_path}" != "Cargo.toml" ]] && ! grep -Eq '^ *\[workspace(\.|\])' "${manifest_path}"; then
        continue
      fi
      m=$(cargo metadata --format-version=1 --no-deps --manifest-path "${manifest_path}" || true)
      if [[ -z "${m}" ]]; then
        continue # Ignore broken manifest
      fi
      dependencies+="$(jq -r '. as $metadata | .workspace_members[] as $id | $metadata.packages[] | select(.id == $id) | .dependencies[].name' <<<"${m}")"$'\n'
    done
    dependencies=$(LC_ALL=C sort -f -u <<<"${dependencies//[0-9_-]/$'\n'}")
  fi
  config_old=$(<.cspell.json)
  config_new=$({ grep -Ev '^ *//' <<<"${config_old}" || true; } | jq 'del(.dictionaries[] | select(index("organization-dictionary") | not)) | del(.dictionaryDefinitions[] | select(.name == "organization-dictionary" | not))')
  trap -- 'printf "%s\n" "${config_old}" >|.cspell.json; printf >&2 "%s\n" "${0##*/}: trapped SIGINT"; exit 1' SIGINT
  printf '%s\n' "${config_new}" >|.cspell.json
  dependencies_words=''
  if [[ -n "${has_rust}" ]]; then
    dependencies_words=$({ cspell stdin --no-progress --no-summary --words-only --unique <<<"${dependencies}" || true; } | LC_ALL=C sort -f)
    if [[ -n "${dependencies_words}" ]]; then
      dependencies_words=$'\n\n'"${dependencies_words}"
    fi
  fi
  all_words=$(ls_files | { grep -Fv "${project_dictionary}" || true; } | cspell --file-list stdin --no-progress --no-summary --words-only --unique || true)
  all_words+=$'\n'$(ls_files | cspell stdin --no-progress --no-summary --words-only --unique || true)
  printf '%s\n' "${config_old}" >|.cspell.json
  trap -- 'printf >&2 "%s\n" "${0##*/}: trapped SIGINT"; exit 1' SIGINT
  cat >|.github/.cspell/rust-dependencies.txt <<EOF
# This file is @generated by ${TIDY_CALLER##*/}.
# It is not intended for manual editing.${dependencies_words}
EOF
  if [[ -z "${CI:-}" ]]; then
    REMOVE_UNUSED_WORDS=1
  fi
  if [[ -z "${REMOVE_UNUSED_WORDS:-}" ]]; then
    check_diff .github/.cspell/rust-dependencies.txt
  fi
  if ! grep -Fq '.github/.cspell/rust-dependencies.txt linguist-generated' .gitattributes; then
    error "you may want to mark .github/.cspell/rust-dependencies.txt linguist-generated"
  fi

  # Check file names.
  info "running \`git ls-files | cspell stdin --no-progress --no-summary --show-context\`"
  if ! ls_files | cspell stdin --no-progress --no-summary --show-context; then
    error "spellcheck failed: please fix uses of below words in file names or add to ${project_dictionary} if correct"
    printf '=======================================\n'
    { ls_files | cspell stdin --no-progress --no-summary --words-only || true; } | sed -E "s/'s$//g" | LC_ALL=C sort -f -u
    printf '=======================================\n\n'
  fi
  # Check file contains.
  info "running \`git ls-files | cspell --file-list stdin --no-progress --no-summary\`"
  if ! ls_files | cspell --file-list stdin --no-progress --no-summary; then
    error "spellcheck failed: please fix uses of below words or add to ${project_dictionary} if correct"
    printf '=======================================\n'
    { ls_files | cspell --file-list stdin --no-progress --no-summary --words-only || true; } | sed -E "s/'s$//g" | LC_ALL=C sort -f -u
    printf '=======================================\n\n'
  fi

  # Make sure the project-specific dictionary does not contain duplicated words.
  for dictionary in .github/.cspell/*.txt; do
    if [[ "${dictionary}" == "${project_dictionary}" ]]; then
      continue
    fi
    dup=$(sed -E 's/#.*//g; s/^[ \t]+//g; s/\/[ \t]+$//g; /^$/d' "${project_dictionary}" "${dictionary}" | LC_ALL=C sort -f | LC_ALL=C uniq -d -i)
    if [[ -n "${dup}" ]]; then
      error "duplicated words in dictionaries; please remove the following words from ${project_dictionary}"
      print_fenced "${dup}"$'\n'
    fi
  done

  # Make sure the project-specific dictionary does not contain unused words.
  if [[ -n "${REMOVE_UNUSED_WORDS:-}" ]]; then
    grep_args=()
    while IFS= read -r word; do
      if ! grep -Eqi "^${word}$" <<<"${all_words}"; then
        grep_args+=(-e "^[ \t]*${word}[ \t]*(#.*|$)")
      fi
    done < <(sed -E 's/#.*//g; s/^[ \t]+//g; s/\/[ \t]+$//g; /^$/d' "${project_dictionary}")
    if [[ ${#grep_args[@]} -gt 0 ]]; then
      info "removing unused words from ${project_dictionary}"
      info "please commit changes made by the removal above"
      res=$(grep -Ev "${grep_args[@]}" "${project_dictionary}" || true)
      if [[ -n "${res}" ]]; then
        printf '%s\n' "${res}" >|"${project_dictionary}"
      else
        printf '' >|"${project_dictionary}"
      fi
    fi
  else
    unused=''
    while IFS= read -r word; do
      if ! grep -Eqi "^${word}$" <<<"${all_words}"; then
        unused+="${word}"$'\n'
      fi
    done < <(sed -E 's/#.*//g; s/^[ \t]+//g; s/\/[ \t]+$//g; /^$/d' "${project_dictionary}")
    if [[ -n "${unused}" ]]; then
      error "unused words in dictionaries; please remove the following words from ${project_dictionary} or run ${TIDY_CALLER} locally"
      print_fenced "${unused}"
    fi
  fi
  printf '\n'
fi

if [[ -n "${should_fail:-}" ]]; then
  exit 1
fi

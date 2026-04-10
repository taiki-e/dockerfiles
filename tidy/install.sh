#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
# Adapted from https://github.com/taiki-e/install-action/blob/v2.75.4/main.sh

rx() {
  (
    set -x
    "$@"
  )
}
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
bail() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::error::%s\n' "$*"
  else
    printf >&2 'error: %s\n' "$*"
  fi
  exit 1
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
normalize_comma_or_space_separated() {
  # Normalize whitespace characters into space because it's hard to handle single input contains lines with POSIX sed alone.
  local list="${1//[$'\r\n\t']/ }"
  if [[ "${list}" == *","* ]]; then
    # If a comma is contained, consider it is a comma-separated list.
    # Drop leading and trailing whitespaces in each element.
    sed -E 's/ *, */,/g; s/^.//' <<<",${list},"
  else
    # Otherwise, consider it is a whitespace-separated list.
    # Convert whitespace characters into comma.
    sed -E 's/ +/,/g; s/^.//' <<<" ${list} "
  fi
}
download_and_checksum() {
  local url="$1"
  local checksum="$2"
  info "downloading ${url}"
  retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 -o tmp "${url}"
  info "verifying sha256 checksum for $(basename -- "${url}")"
  sha256sum -c - >/dev/null <<<"${checksum} *tmp"
}
download_and_extract() {
  local url="$1"
  shift
  local checksum="$1"
  shift
  local bin_dir="$1"
  shift
  local bin_in_archive=("$@") # path to bin in archive
  if [[ "${bin_dir}" == "${install_action_dir}/bin" ]]; then
    init_install_action_bin_dir
  fi

  installed_bin=()
  local tmp
  case "${tool}" in
    # editorconfig-checker's binary name is renamed below
    editorconfig-checker) installed_bin=("${bin_dir}/${tool}${exe}") ;;
    *)
      for tmp in "${bin_in_archive[@]}"; do
        installed_bin+=("${bin_dir}/$(basename -- "${tmp}")")
      done
      ;;
  esac

  local tar_args=()
  case "${url}" in
    *.tar.gz | *.tgz) tar_args+=('xzf') ;;
    *.tar.bz2 | *.tbz2) tar_args+=('xjf') ;;
    *.tar.xz | *.txz) tar_args+=('xJf') ;;
  esac

  mkdir -p -- "${tmp_dir}"
  (
    cd -- "${tmp_dir}"
    download_and_checksum "${url}" "${checksum}"
    if [[ ${#tar_args[@]} -gt 0 ]]; then
      tar_args+=("tmp")
      tar "${tar_args[@]}"
      for tmp in "${bin_in_archive[@]}"; do
        case "${tool}" in
          editorconfig-checker) mv -- "${tmp}" "${bin_dir}/${tool}${exe}" ;;
          *) mv -- "${tmp}" "${bin_dir}/" ;;
        esac
      done
    else
      case "${url}" in
        *.zip)
          unzip -q tmp
          for tmp in "${bin_in_archive[@]}"; do
            case "${tool}" in
              editorconfig-checker) mv -- "${tmp}" "${bin_dir}/${tool}${exe}" ;;
              *) mv -- "${tmp}" "${bin_dir}/" ;;
            esac
          done
          ;;
        *.gz)
          mv -- tmp "${bin_in_archive#\./}.gz"
          gzip -d "${bin_in_archive#\./}.gz"
          for tmp in "${bin_in_archive[@]}"; do
            mv -- "${tmp}" "${bin_dir}/"
          done
          ;;
        *)
          for tmp in "${installed_bin[@]}"; do
            mv -- tmp "${tmp}"
          done
          ;;
      esac
    fi
  )
  rm -rf -- "${tmp_dir}"

  for tmp in "${installed_bin[@]}"; do
    if [[ ! -x "${tmp}" ]]; then
      chmod +x "${tmp}"
    fi
  done
}
read_manifest() {
  local tool="$1"
  local version="$2"
  local manifest
  rust_crate=$(jq -r '.rust_crate' "${manifest_dir}/${tool}.json")
  manifest=$(jq -r --arg version "${version}" '.[$version]' "${manifest_dir}/${tool}.json")
  if [[ "${manifest}" == "null" ]]; then
    download_info="null"
    return 0
  fi
  exact_version=$(jq -r '.version' <<<"${manifest}")
  if [[ "${exact_version}" == "null" ]]; then
    exact_version="${version}"
  else
    manifest=$(jq -r --arg version "${exact_version}" '.[$version]' "${manifest_dir}/${tool}.json")
  fi

  # Static-linked binaries compiled for linux-musl will also work on linux-gnu systems and are
  # usually preferred over linux-gnu binaries because they can avoid glibc version issues.
  # (rustc enables statically linking for linux-musl by default, except for mips.)
  host_platform="${host_arch}_linux_musl"
  download_info=$(jq -r --arg p "${host_platform}" '.[$p]' <<<"${manifest}")
  if [[ "${download_info}" == "null" ]]; then
    # Even if host_env is musl, we won't issue an error here because it seems that in
    # some cases linux-gnu binaries will work on linux-musl hosts.
    # https://wiki.alpinelinux.org/wiki/Running_glibc_programs
    # TODO: However, a warning may make sense.
    host_platform="${host_arch}_linux_gnu"
    download_info=$(jq -r --arg p "${host_platform}" '.[$p]' <<<"${manifest}")
  fi
}
read_download_info() {
  local tool="$1"
  local version="$2"
  if [[ "${download_info}" == "null" ]]; then
    bail "${tool}@${version} for '${host_os}' is not supported"
  fi
  checksum=$(jq -r '.hash' <<<"${download_info}")
  url=$(jq -r '.url' <<<"${download_info}")
  local tmp
  bin_in_archive=()
  if [[ "${url}" == "null" ]]; then
    local template
    template=$(jq -c --arg p "${host_platform}" '.template[$p]' "${manifest_dir}/${tool}.json")
    template="${template//\$\{version\}/${exact_version}}"
    url=$(jq -r '.url' <<<"${template}")
    tmp=$(jq -r '.bin' <<<"${template}")
    if [[ "${tmp}" == *"["* ]]; then
      # shellcheck disable=SC2207
      bin_in_archive=($(jq -r '.bin[]' <<<"${template}"))
    fi
  else
    tmp=$(jq -r '.bin' <<<"${download_info}")
    if [[ "${tmp}" == *"["* ]]; then
      # shellcheck disable=SC2207
      bin_in_archive=($(jq -r '.bin[]' <<<"${download_info}"))
    fi
  fi
  if [[ ${#bin_in_archive[@]} -eq 0 ]]; then
    if [[ "${tmp}" == "null" ]]; then
      bin_in_archive=("${tool}${exe}")
    else
      bin_in_archive=("${tmp}")
    fi
  fi
  if [[ "${rust_crate}" == "null" ]]; then
    # Moving files to /usr/local/bin requires sudo in some environments, so do not use it: https://github.com/taiki-e/install-action/issues/543
    bin_dir="${install_action_dir}/bin"
  else
    bin_dir="${cargo_bin}"
  fi
}
download_from_manifest() {
  read_manifest "$@"
  download_from_download_info "$@"
}
download_from_download_info() {
  read_download_info "$@"
  download_and_extract "${url}" "${checksum}" "${bin_dir}" "${bin_in_archive[@]}"
}
init_install_action_bin_dir() {
  if [[ -z "${init_install_action_bin:-}" ]]; then
    init_install_action_bin=1
    mkdir -p -- "${bin_dir}"
  fi
}

if [[ $# -gt 0 ]]; then
  bail "invalid argument '$1'"
fi

export RUSTUP_MAX_RETRIES=10
export DEBIAN_FRONTEND=noninteractive
manifest_dir="$(dirname -- "$0")/manifests"

# Inputs
tool="${INPUT_TOOL:-}"
tools=()
if [[ -n "${tool}" ]]; then
  while read -rd,; do
    tools+=("${REPLY}")
  done < <(normalize_comma_or_space_separated "${tool}")
fi
if [[ ${#tools[@]} -eq 0 ]]; then
  warn "no tool specified; this could be caused by a dependabot bug where @<tool_name> tags on this action are replaced by @<version> tags"
  # Exit with 0 for backward compatibility.
  # TODO: We want to reject it in the next major release.
  exit 0
fi

# Refs: https://github.com/rust-lang/rustup/blob/HEAD/rustup-init.sh
exe=''
host_os=linux
# NB: Sync with tools/ci/tool-list.sh.
case "$(uname -m)" in
  aarch64 | arm64) host_arch=aarch64 ;;
  # Ignore 32-bit Arm for now, as we need to consider the version and whether hard-float is supported.
  # https://github.com/rust-lang/rustup/pull/593
  # https://github.com/cross-rs/cross/pull/1018
  # And support for 32-bit Arm will be removed in near future.
  # https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/#removal-of-operating-system-support-with-node24
  # Does it seem only armv7l+ is supported?
  # https://github.com/actions/runner/blob/v2.321.0/src/Misc/externals.sh#L178
  # https://github.com/actions/runner/issues/688
  xscale | arm | armv*l) bail "32-bit Arm runner is not supported yet by this action; if you need support for this platform, please submit an issue at <https://github.com/taiki-e/install-action>" ;;
  ppc64le) host_arch=powerpc64le ;;
  riscv64) host_arch=riscv64 ;;
  s390x) host_arch=s390x ;;
  # Very few tools provide prebuilt binaries for these.
  loongarch64 | mips | mips64 | ppc | ppc64 | sun4v) bail "$(uname -m) runner is not supported yet by this action; if you need support for this platform, please submit an issue at <https://github.com/taiki-e/install-action>" ;;
  # GitHub Actions Runner supports x86_64/AArch64/Arm Linux and x86_64/AArch64 Windows/macOS.
  # https://github.com/actions/runner/blob/v2.332.0/.github/workflows/build.yml#L24
  # https://docs.github.com/en/actions/reference/runners/self-hosted-runners#supported-processor-architectures
  # And IBM provides runners for powerpc64le/s390x Linux.
  # https://github.com/IBM/actionspz
  # So we can assume x86_64 unless it has a known non-x86_64 uname -m result.
  # TODO: uname -m on windows-11-arm returns "x86_64"
  *) host_arch=x86_64 ;;
esac
info "host platform: ${host_arch}_${host_os}"

install_action_dir="/usr/local"
tmp_dir="${install_action_dir}/tmp"
cargo_bin="${install_action_dir}/bin"

for tool in "${tools[@]}"; do
  if [[ "${tool}" == *"@"* ]]; then
    version="${tool#*@}"
    tool="${tool%@*}"
    if [[ ! "${version}" =~ ^([1-9][0-9]*(\.[0-9]+(\.[0-9]+)?)?|0\.[1-9][0-9]*(\.[0-9]+)?|^0\.0\.[0-9]+)(-[0-9A-Za-z\.-]+)?$|^latest$ ]]; then
      if [[ ! "${version}" =~ ^([1-9][0-9]*(\.[0-9]+(\.[0-9]+)?)?|0\.[1-9][0-9]*(\.[0-9]+)?|^0\.0\.[0-9]+)(-[0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$|^latest$ ]]; then
        bail "install-action does not support semver operators: '${version}'"
      fi
      bail "install-action v2 does not support semver build-metadata: '${version}'; if you need these supports again, please submit an issue at <https://github.com/taiki-e/install-action>"
    fi
  else
    version=latest
  fi
  installed_bin=()
  case "${tool}" in
    protoc)
      info "installing ${tool}@${version}"
      read_manifest "protoc" "${version}"
      read_download_info "protoc" "${version}"
      bin_dir="${install_action_dir}/bin"
      include_dir="${install_action_dir}/include"
      init_install_action_bin_dir
      if [[ ! -e "${include_dir}" ]]; then
        mkdir -p -- "${include_dir}"
      fi
      mkdir -p -- "${tmp_dir}"
      (
        cd -- "${tmp_dir}"
        download_and_checksum "${url}" "${checksum}"
        unzip -q tmp
        mv -- "bin/protoc${exe}" "${bin_dir}/"
        mkdir -p -- "${include_dir}/"
        cp -r -- include/. "${include_dir}/"
        if [[ -z "${PROTOC:-}" ]]; then
          _bin_dir="${bin_dir}"
          info "setting PROTOC environment variable to '${_bin_dir}/protoc${exe}'"
          printf '%s\n' "PROTOC=${_bin_dir}/protoc${exe}" >>"${GITHUB_ENV}"
        fi
      )
      rm -rf -- "${tmp_dir}"
      installed_bin=("${tool}${exe}")
      ;;
    *)
      if [[ ! -f "${manifest_dir}/${tool}.json" ]]; then
        bail "install-action does not support ${tool}"
      fi

      read_manifest "${tool}" "${version}"
      if [[ "${download_info}" == "null" ]]; then
        bail "${tool}@${version} for '${host_arch}_${host_os}' is not supported"
      fi

      info "installing ${tool}@${version}"
      download_from_download_info "${tool}" "${version}"
      ;;
  esac

  for tool_bin in "${installed_bin[@]}"; do
    tool_bin=$(basename -- "${tool_bin}")
    tool_bin_stem="${tool_bin%.exe}"
    installed_at=$(type -P "${tool_bin}" || true)
    if [[ -z "${installed_at}" ]]; then
      tool_bin="${tool_bin_stem}"
      installed_at=$(type -P "${tool_bin}" || true)
    fi
    if [[ -n "${installed_at}" ]]; then
      info "${tool_bin_stem} installed at ${installed_at}"
    else
      warn "${tool_bin_stem} should be installed at ${bin_dir:+"${bin_dir}/"}${tool_bin}${exe}; but ${tool_bin}${exe} not found in path"
    fi
  done
  printf '\n'
done

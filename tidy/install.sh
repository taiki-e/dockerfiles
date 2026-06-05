#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
# Adapted from https://github.com/taiki-e/install-action/blob/v2.81.4/main.sh.

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
    printf '::error::install-action: %s\n' "$*"
  else
    printf >&2 'error: install-action: %s\n' "$*"
  fi
  exit 1
}
warn() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::warning::install-action: %s\n' "$*"
  else
    printf >&2 'warning: install-action: %s\n' "$*"
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
    sed -E 's/ *\+ */+/g; s/ *, */,/g; s/^.//; s/,,$/,/' <<<",${list},"
  else
    # Otherwise, consider it is a whitespace-separated list.
    # Convert whitespace characters into comma.
    sed -E 's/ *\+ */+/g; s/ +/,/g; s/^.//' <<<" ${list} "
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
        *.deb)
          dpkg-deb -x tmp .
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

# Inputs
tool="${INPUT_TOOL:-}"
tools=()
if [[ -n "${tool}" ]]; then
  while IFS= read -rd,; do
    tools+=("${REPLY}")
  done < <(normalize_comma_or_space_separated "${tool}")
fi
if [[ ${#tools[@]} -eq 0 ]]; then
  warn "no tool specified; this could be caused by a dependabot bug where @<tool_name> tags on this action are replaced by @<version> tags"
  # Exit with 0 for backward compatibility.
  # TODO: We want to reject it in the next major release.
  exit 0
fi

# Refs:
# - https://github.com/rust-lang/rustup/blob/HEAD/rustup-init.sh
# - https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#runner-context
# NB: Sync with tools/ci/tool-list.sh.
exe=''
host_os=linux
ldd_version=$(ldd --version 2>&1 || true)
if [[ "${ldd_version}" == *'musl'* ]]; then
  host_env=musl
else
  host_env=gnu
fi
host_arch="$(uname -m)"
case "${host_arch}" in
  aarch64 | arm64) host_arch=aarch64 ;;
  ppc64le) host_arch=powerpc64le ;;
  riscv64) host_arch=riscv64 ;;
  s390x) host_arch=s390x ;;
  # On these platforms, we just use the result of `uname -m` as host_arch, and always fallback to `cargo install`.
  xscale | arm | armv*l | loongarch64 | mips | mips64 | ppc | ppc64 | sun4v) ;;
  # GitHub Actions Runner supports x86_64/AArch64/Arm Linux and x86_64/AArch64 Windows/macOS.
  # https://github.com/actions/runner/blob/v2.332.0/.github/workflows/build.yml#L24
  # https://docs.github.com/en/actions/reference/runners/self-hosted-runners#supported-processor-architectures
  # And IBM provides runners for powerpc64le/s390x Linux.
  # https://github.com/IBM/actionspz
  # So we can assume x86_64 unless it has a known non-x86_64 uname -m result.
  *) host_arch=x86_64 ;;
esac
info "host platform: ${host_arch}_${host_os}"

install_action_dir="/usr/local"
tmp_dir="${install_action_dir}/tmp"
cargo_bin="${install_action_dir}/bin"

export CARGO_NET_RETRY=10
export RUSTUP_MAX_RETRIES=10

export DEBIAN_FRONTEND=noninteractive
manifest_dir="$(dirname -- "$0")/manifests"

for tool in "${tools[@]}"; do
  additional=''
  if [[ "${tool}" == *'+'* ]]; then
    additional="${tool#*+}"
    tool="${tool%%+*}"
  fi
  if [[ "${tool}" == *'@'* ]]; then
    version="${tool#*@}"
    tool="${tool%@*}"
    if [[ "${tool}" != 'rust' ]]; then
      if [[ ! "${version}" =~ ^([1-9][0-9]*(\.[0-9]+(\.[0-9]+)?)?|0\.[1-9][0-9]*(\.[0-9]+)?|^0\.0\.[0-9]+)(-[0-9A-Za-z\.-]+)?$|^latest$ ]]; then
        if [[ ! "${version}" =~ ^([1-9][0-9]*(\.[0-9]+(\.[0-9]+)?)?|0\.[1-9][0-9]*(\.[0-9]+)?|^0\.0\.[0-9]+)(-[0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$|^latest$ ]]; then
          bail "semver operators are not supported in 'tool' input option: '${version}'"
        fi
        bail "install-action v2 does not support semver build-metadata: '${version}'; if you need these supports again, please submit an issue at <https://github.com/taiki-e/install-action>"
      fi
    fi
  else
    version=latest
  fi
  if [[ -n "${additional}" ]]; then
    case "${tool}" in
      rust) ;;
      *) bail "<tool_name>+<additional> syntax is not supported for ${tool}" ;;
    esac
  fi
  installed_bin=()
  case "${tool}" in
    rust)
      if [[ "${version}" == 'latest' ]]; then
        version=stable
      fi
      info "installing ${tool}@${version}"
      rustup_args=(--profile minimal)
      if [[ -n "${additional}" ]]; then
        component=''
        target=''
        while IFS= read -rd+; do
          case "${REPLY}" in
            # Last checked: nightly-2026-05-03
            # rustup component list
            # rustup target list
            cargo | cargo-* | clippy | clippy-* | llvm-* | miri | miri-* | rust-* | rustc-* | rustfmt | rustfmt-*) component+=",${REPLY}" ;;
            *) target+=",${REPLY}" ;;
          esac
        done <<<"${additional}+"
        if [[ -n "${component}" ]]; then
          if [[ "${component}," == *',miri,'* ]] && [[ "${component}," != *',rust-src,'* ]]; then
            component+=',rust-src'
          fi
          rustup_args+=(--component "${component#,}")
        fi
        if [[ -n "${target}" ]]; then
          rustup_args+=(--target "${target#,}")
        fi
      fi
      if type -P rustup >/dev/null; then
        # --no-self-update is necessary because the windows environment cannot self-update rustup.exe.
        rx retry rustup toolchain add "${version}" --no-self-update "${rustup_args[@]}"
        rx rustup default "${version}"
      else
        # https://github.com/rust-lang/rustup/tags
        # Run tools/rustup-hash.sh to get sha256 hash.
        rustup_version=1.29.0
        # https://rust-lang.github.io/rustup/installation/other.html#manual-installation
        rust_target=''
        checksum=''
        rust_target="${host_arch}-unknown-${host_os}-${host_env}"
        case "${host_arch}" in
          x86_64)
            case "${host_env}" in
              gnu) checksum=4acc9acc76d5079515b46346a485974457b5a79893cfb01112423c89aeb5aa10 ;;
              musl) checksum=9cd3fda5fd293890e36ab271af6a786ee22084b5f6c2b83fd8323cec6f0992c1 ;;
            esac
            ;;
          aarch64)
            case "${host_env}" in
              gnu) checksum=9732d6c5e2a098d3521fca8145d826ae0aaa067ef2385ead08e6feac88fa5792 ;;
              musl) checksum=88761caacddb92cd79b0b1f939f3990ba1997d701a38b3e8dd6746a562f2a759 ;;
            esac
            ;;
          powerpc64le)
            case "${host_env}" in
              gnu) checksum=4bfff85bd3967d988e14567aa9cc6ab0ea386f0ffeff0f9f14d23f0103bf1f97 ;;
              musl) checksum=e15d033af90b7a55d170aac2d82cc28ddd96dbfcdda7c6d4eb8cb064a99c4646 ;;
            esac
            ;;
          riscv64)
            rust_target="${host_arch}gc-unknown-${host_os}-${host_env}"
            # riscv64gc-unknown-linux-musl is tier 2 without host tools
            case "${host_env}" in
              gnu) checksum=7e43f2b2e6307d61da17a4dff61e6bceef408b8189822df64e1094590d2a70f9 ;;
            esac
            ;;
          s390x)
            # s390x-unknown-linux-musl is tier 3
            case "${host_env}" in
              gnu) checksum=66c2c132428b6b77803facb02cbdf33b89d20c00bd20da142be8cb651f2e7cd8 ;;
            esac
            ;;
        esac
        if [[ -z "${rust_target}" ]] || [[ -z "${checksum}" ]]; then
          bail "unsupported host platform ${host_arch}_${host_os} for ${tool}"
        fi
        url="https://static.rust-lang.org/rustup/archive/${rustup_version}/${rust_target}/rustup-init${exe}"
        mkdir -p -- "${tmp_dir}"
        (
          cd -- "${tmp_dir}"
          download_and_checksum "${url}" "${checksum}"
          mv -- tmp rustup-init
          case "${host_os}" in
            linux | macos) chmod +x ./rustup-init ;;
          esac
          rx retry ./rustup-init -y --default-toolchain "${version}" --no-modify-path "${rustup_args[@]}"
        )
        rm -rf -- "${tmp_dir}"
      fi
      installed_bin=("rustc${exe}" "cargo${exe}")
      ;;
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
          printf 'PROTOC=%s\n' "${_bin_dir}/protoc${exe}" >>"${GITHUB_ENV}"
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
        bail "${tool} is supported but version ${version} for '${host_arch}_${host_os}' is not supported"
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

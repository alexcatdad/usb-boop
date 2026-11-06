#!/usr/bin/env bash
# Prepares a GitHub-hosted macos-26 runner for the repository's Task commands:
# selects the pinned Xcode, installs Task and XcodeGen, and installs pinned
# actionlint and shellcheck (`task lint` requires both). Local machines install
# the tools once with Homebrew (see AGENTS.md) and do not need this.

set -euo pipefail

xcode="/Applications/Xcode_26.6.app/Contents/Developer"
if [[ -d "${xcode}" ]]; then
  sudo xcode-select -s "${xcode}"
fi
xcodebuild -version
swift format --version

[[ "${1:-}" == "--no-tools" ]] && exit 0

brew install go-task xcodegen

# Pinned lint tools. Digests are the upstream GitHub release asset digests.
actionlint_version=1.7.12
actionlint_digest=aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f
shellcheck_version=0.11.0
shellcheck_digest=339b930feb1ea764467013cc1f72d09cd6b869ebf1013296ba9055ab2ffbd26f

[[ "$(uname -s)-$(uname -m)" == "Darwin-arm64" ]] || {
  echo "ci_setup: pinned lint tools support macOS arm64 only" >&2
  exit 2
}

bin="$(brew --prefix)/bin" # on PATH for the commands that follow
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

fetch() {
  local url="$1" digest="$2" out="$3"
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "${url}" -o "${out}"
  printf '%s  %s\n' "${digest}" "${out}" | shasum -a 256 -c - >/dev/null
}

if ! actionlint -version 2>/dev/null | grep -qx "${actionlint_version}"; then
  fetch "https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/actionlint_${actionlint_version}_darwin_arm64.tar.gz" \
    "${actionlint_digest}" "${work}/actionlint.tar.gz"
  tar -xzf "${work}/actionlint.tar.gz" -C "${work}" actionlint
  install -m 755 "${work}/actionlint" "${bin}/actionlint"
fi

if ! shellcheck --version 2>/dev/null | grep -qx "version: ${shellcheck_version}"; then
  fetch "https://github.com/koalaman/shellcheck/releases/download/v${shellcheck_version}/shellcheck-v${shellcheck_version}.darwin.aarch64.tar.gz" \
    "${shellcheck_digest}" "${work}/shellcheck.tar.gz"
  tar -xzf "${work}/shellcheck.tar.gz" -C "${work}" "shellcheck-v${shellcheck_version}/shellcheck"
  install -m 755 "${work}/shellcheck-v${shellcheck_version}/shellcheck" "${bin}/shellcheck"
fi

actionlint -version | head -1
shellcheck --version | sed -n 2p

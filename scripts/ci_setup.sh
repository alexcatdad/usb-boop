#!/usr/bin/env bash
# Prepares a GitHub-hosted macos-26 runner for the repository's Task commands:
# selects the pinned Xcode and installs the build-time tools. Local machines
# install the tools once with Homebrew (see AGENTS.md) and do not need this.

set -euo pipefail

xcode="/Applications/Xcode_26.6.app/Contents/Developer"
if [[ -d "${xcode}" ]]; then
  sudo xcode-select -s "${xcode}"
fi
xcodebuild -version

if [[ "${1:-}" != "--no-tools" ]]; then
  brew install go-task xcodegen swiftlint actionlint shellcheck
fi

#!/usr/bin/env bash
# Generates the cask with update_homebrew_tap.sh from placeholder values and
# lints it in a throwaway local tap. The real cask is written at release time,
# so this is the only check of its syntax and style before it reaches the tap.

set -euo pipefail

tap="alexcatdad/caskcheck"
work="$(mktemp -d)"
cleanup() {
  brew untap "${tap}" >/dev/null 2>&1 || true
  rm -rf "${work}"
}
trap cleanup EXIT

./scripts/update_homebrew_tap.sh \
  "${work}" \
  "2026.01.01.1" \
  "0000000000000000000000000000000000000000000000000000000000000000" \
  "https://github.com/alexcatdad/usb-boop/releases/download/v2026.01.01.1/usb-boop-macos-arm64.zip"

brew untap "${tap}" >/dev/null 2>&1 || true
brew tap-new "${tap}" --no-git >/dev/null
mkdir -p "$(brew --repository "${tap}")/Casks"
cp "${work}/Casks/usb-boop.rb" "$(brew --repository "${tap}")/Casks/"
brew style --cask "${tap}/usb-boop"
brew trust --cask "${tap}/usb-boop"
# Style alone does not reject deprecated cask DSL options.
HOMEBREW_DEVELOPER=1 brew info --cask "${tap}/usb-boop" >/dev/null
echo "cask: ok"

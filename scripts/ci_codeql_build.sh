#!/usr/bin/env bash
# Build traced by CodeQL. It runs after codeql-action/init, which puts every
# step under Rosetta, so it installs nothing (Homebrew refuses translated
# installs) and builds the committed, XcodeGen-generated project for
# generic/platform=macOS: under Rosetta xcodebuild reports "My Mac" as x86_64
# and nothing matches this arm64-only project. CodeQL needs the compilation,
# not a runnable destination.

set -euo pipefail

./scripts/ci_setup.sh --no-tools
xcodebuild \
  -project usb-boop.xcodeproj \
  -scheme usb-boop \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

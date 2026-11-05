#!/usr/bin/env bash

# Build, sign and package the Release app as a zip. Called by the
# `build:darwin-arm64` Go Task target; reltool provides the version and the
# output directory, and signs-verifies, notarizes and staples afterwards.
#
# Required environment (set by reltool):
#   RELEASE_OUT              output directory for the final artifact
#   MACOS_SHORT_VERSION      CFBundleShortVersionString (YYYY.MMDD.N)
#   MACOS_BUNDLE_VERSION     CFBundleVersion (YYYY.MMDD.N)
#   MACOS_SIGNING_IDENTITY   Developer ID Application identity (signed targets)
#   MACOS_ENTITLEMENTS       absolute path of the entitlements file
#   RELEASE_VERSION          optional; when set, both bundle versions must match it
# Set USB_BOOP_UNSIGNED_BUILD=1 to package without signing; this is only for
# proving the build and cannot pass a signed target's signature verification.
set -euo pipefail

: "${RELEASE_OUT:?RELEASE_OUT is required}"
: "${MACOS_SHORT_VERSION:?MACOS_SHORT_VERSION is required}"
: "${MACOS_BUNDLE_VERSION:?MACOS_BUNDLE_VERSION is required}"
output_dir="${RELEASE_OUT}"
# shellcheck source=scripts/release_version.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release_version.sh"
for apple_version in "${MACOS_SHORT_VERSION}" "${MACOS_BUNDLE_VERSION}"; do
  if ! is_apple_version "${apple_version}"; then
    echo "expected an Apple bundle version (YYYY.MMDD.N), got ${apple_version}" >&2
    exit 1
  fi
done
if [[ -n "${RELEASE_VERSION:-}" ]]; then
  expected="$(apple_version_for "${RELEASE_VERSION}")" \
    || { echo "expected a CalVer release version (YYYY.MM.DD.N), got ${RELEASE_VERSION}" >&2; exit 1; }
  if [[ "${MACOS_SHORT_VERSION}" != "${expected}" || "${MACOS_BUNDLE_VERSION}" != "${expected}" ]]; then
    echo "bundle versions must be ${expected} for release ${RELEASE_VERSION}" >&2
    exit 1
  fi
fi
unsigned="${USB_BOOP_UNSIGNED_BUILD:-}"
sign_identity="${MACOS_SIGNING_IDENTITY:-}"
entitlements="${MACOS_ENTITLEMENTS:-}"
if [[ -z "${unsigned}" ]]; then
  if [[ "${sign_identity}" != "Developer ID Application: "* ]]; then
    echo "MACOS_SIGNING_IDENTITY must be a Developer ID Application identity" >&2
    exit 1
  fi
  [[ -f "${entitlements}" ]] || { echo "MACOS_ENTITLEMENTS must name the entitlements file" >&2; exit 1; }
fi

derived_data_path="${DERIVED_DATA_PATH:-${TMPDIR:-$(pwd)/.build}/DerivedData}"
artifact_name="usb-boop-macos-arm64.zip"
artifact_path="${output_dir}/${artifact_name}"

rm -rf "${derived_data_path}"
mkdir -p "${output_dir}"

xcodegen generate

xcodebuild \
  -project usb-boop.xcodeproj \
  -scheme usb-boop \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "${derived_data_path}" \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="${MACOS_SHORT_VERSION}" \
  CURRENT_PROJECT_VERSION="${MACOS_BUNDLE_VERSION}" \
  build

app_path="${derived_data_path}/Build/Products/Release/usb-boop.app"
if [[ ! -d "${app_path}" ]]; then
  echo "expected app bundle at ${app_path}" >&2
  exit 1
fi

if [[ -z "${unsigned}" ]]; then
  # The build runs with CODE_SIGNING_ALLOWED=NO, so this is the only signature
  # the bundle gets. The entitlements must be passed explicitly or the App
  # Sandbox is silently dropped from the shipped app.
  #
  # Release packaging always requires the local Developer ID private key. Debug
  # builds remain independent. The key is never exported to CI.
  sign_opts=(--force --sign "${sign_identity}" --options runtime --timestamp)

  # Sign inside-out: nested code first, then the bundle that contains it.
  codesign "${sign_opts[@]}" "${app_path}/Contents/Frameworks/USBBoopKit.framework/Versions/A"
  codesign "${sign_opts[@]}" --entitlements "${entitlements}" "${app_path}"
  echo "Signed ${app_path}"

  # Fail loudly if the shipped bundle lost its sandbox.
  if ! codesign --display --entitlements - --xml "${app_path}" 2>/dev/null \
    | grep -q 'com.apple.security.app-sandbox'; then
    echo "signed bundle is missing the App Sandbox entitlement" >&2
    exit 1
  fi
  codesign --verify --deep --strict --verbose=2 "${app_path}"
fi

rm -f "${artifact_path}"
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${artifact_path}"

echo "artifact_path=${artifact_path}"

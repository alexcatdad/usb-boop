#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <version> <output-dir>" >&2
  exit 1
fi

version="$1"
output_dir="$2"

derived_data_path="${DERIVED_DATA_PATH:-$(pwd)/.build/DerivedData}"
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
  MARKETING_VERSION="${version}" \
  CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}" \
  build

app_path="${derived_data_path}/Build/Products/Release/usb-boop.app"
if [[ ! -d "${app_path}" ]]; then
  echo "expected app bundle at ${app_path}" >&2
  exit 1
fi

# The build runs with CODE_SIGNING_ALLOWED=NO, so this is the only signature
# the bundle gets. The entitlements must be passed explicitly or the App
# Sandbox is silently dropped from the shipped app.
#
# Defaults to ad-hoc so Gatekeeper doesn't flag the app as "damaged". Set
# CODESIGN_IDENTITY to a Developer ID Application identity to sign for real;
# that is also the only case where Hardened Runtime can be enabled, because it
# turns on library validation and an ad-hoc signature has no Team ID for the
# embedded USBBoopKit.framework to match.
sign_identity="${CODESIGN_IDENTITY:--}"
sign_opts=(--force --sign "${sign_identity}")
if [[ "${sign_identity}" != "-" ]]; then
  sign_opts+=(--options runtime --timestamp)
else
  echo "warning: signing ad-hoc; Hardened Runtime and notarization are skipped" >&2
fi

# Sign inside-out: nested code first, then the bundle that contains it.
codesign "${sign_opts[@]}" "${app_path}/Contents/Frameworks/USBBoopKit.framework/Versions/A"
codesign "${sign_opts[@]}" \
  --entitlements Sources/App/usb-boop.entitlements \
  "${app_path}"
echo "Signed ${app_path} with identity '${sign_identity}'"

# Fail loudly if the shipped bundle lost its sandbox.
if ! codesign --display --entitlements - --xml "${app_path}" 2>/dev/null \
  | grep -q 'com.apple.security.app-sandbox'; then
  echo "signed bundle is missing the App Sandbox entitlement" >&2
  exit 1
fi
codesign --verify --strict --verbose=2 "${app_path}"

rm -f "${artifact_path}"
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${artifact_path}"

sha256="$(shasum -a 256 "${artifact_path}" | awk '{print $1}')"
checksum_path="${artifact_path%.zip}.sha256"
printf "%s  %s\n" "${sha256}" "${artifact_name}" > "${checksum_path}"

echo "artifact_path=${artifact_path}"
echo "artifact_name=${artifact_name}"
echo "sha256=${sha256}"
echo "checksum_path=${checksum_path}"

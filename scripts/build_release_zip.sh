#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <version> <output-dir>" >&2
  exit 1
fi

version="$1"
output_dir="$2"
if [[ ! "${version}" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
  echo "expected a CalVer version: YYYY.MM.DD.N" >&2
  exit 1
fi
sign_identity="${CODESIGN_IDENTITY:-}"
if [[ "${sign_identity}" != "Developer ID Application: "* ]]; then
  echo "set CODESIGN_IDENTITY to your local Developer ID Application identity" >&2
  exit 1
fi

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
# Release packaging always requires the local Developer ID private key. Debug
# builds remain independent. The key is never exported to CI.
sign_opts=(--force --sign "${sign_identity}" --options runtime --timestamp)

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
codesign --verify --deep --strict --verbose=2 "${app_path}"

rm -f "${artifact_path}"
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${artifact_path}"

sha256="$(shasum -a 256 "${artifact_path}" | awk '{print $1}')"
checksum_path="${artifact_path%.zip}.sha256"
printf "%s  %s\n" "${sha256}" "${artifact_name}" > "${checksum_path}"

echo "artifact_path=${artifact_path}"
echo "artifact_name=${artifact_name}"
echo "sha256=${sha256}"
echo "checksum_path=${checksum_path}"

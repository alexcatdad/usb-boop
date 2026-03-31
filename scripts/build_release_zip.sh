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

# Ad-hoc sign so Gatekeeper doesn't flag the app as "damaged".
# Replace with Developer ID signing when available.
codesign --force --sign - "${app_path}"
echo "Ad-hoc signed ${app_path}"

rm -f "${artifact_path}"
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${artifact_path}"

sha256="$(shasum -a 256 "${artifact_path}" | awk '{print $1}')"
checksum_path="${artifact_path%.zip}.sha256"
printf "%s  %s\n" "${sha256}" "${artifact_name}" > "${checksum_path}"

echo "artifact_path=${artifact_path}"
echo "artifact_name=${artifact_name}"
echo "sha256=${sha256}"
echo "checksum_path=${checksum_path}"

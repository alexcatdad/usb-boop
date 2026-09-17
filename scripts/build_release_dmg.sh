#!/usr/bin/env bash

# Package the already signed/stapled app from the published ZIP. Layout is
# written directly into the image; no Finder automation or preferences change.
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo "usage: $0 <notarized-release.zip> <YYYY.MM.DD.N> <output-dir>" >&2
  exit 1
fi
archive="$1"
version="$2"
output_dir="$3"
sign_identity="${CODESIGN_IDENTITY:-}"
if [[ "${sign_identity}" != 'Developer ID Application: '* ]]; then
  echo 'Set CODESIGN_IDENTITY to your local Developer ID Application identity.' >&2
  exit 1
fi
script_dir="$(cd "$(dirname "$0")" && pwd)"
dmg_python="${DMG_PYTHON:-${script_dir}/../.build/dmg-tools/bin/python}"
[[ -x "${dmg_python}" ]] || { echo 'Install scripts/dmg-requirements.txt in .build/dmg-tools first.' >&2; exit 1; }
"${script_dir}/verify_release_artifact.sh" "${archive}" "${version}"
mkdir -p "${output_dir}"
output_dir="$(cd "${output_dir}" && pwd)"
output="${output_dir}/usb-boop-macos-arm64.dmg"
[[ ! -e "${output}" ]] || { echo "Refusing to overwrite ${output}" >&2; exit 1; }
work_dir="$(mktemp -d)"
mount_path="${work_dir}/mounted"
mounted=false
cleanup() {
  local result=$?
  trap - EXIT
  if [[ "${mounted}" == true ]]; then
    if ! hdiutil detach "${mount_path}" -quiet; then
      echo "Could not detach our installer at ${mount_path}; leaving work files for recovery." >&2
      exit 1
    fi
  fi
  rm -rf "${work_dir}"
  exit "${result}"
}
trap cleanup EXIT
mkdir -p "${work_dir}/contents/.background" "${mount_path}"
ditto -x -k "${archive}" "${work_dir}/contents"
rm -rf "${work_dir}/contents/__MACOSX"
ln -s /Applications "${work_dir}/contents/Applications"
swift "${script_dir}/render_dmg_background.swift" "${work_dir}/contents/.background/background.png"
hdiutil create -quiet -size 64m -fs HFS+ -volname usb-boop \
  -srcfolder "${work_dir}/contents" -format UDRW "${work_dir}/installer.dmg"
# Treat a partially successful/interrupted attach as mounted until detached.
# Never remove a work directory while its writable image might still be there.
mounted=true
hdiutil attach "${work_dir}/installer.dmg" -quiet -nobrowse -noautoopen \
  -mountpoint "${mount_path}"

"${dmg_python}" "${script_dir}/write_dmg_layout.py" "${mount_path}"

sync
hdiutil detach "${mount_path}" -quiet
mounted=false
hdiutil convert "${work_dir}/installer.dmg" -quiet -format UDZO -o "${output}"
codesign --force --sign "${sign_identity}" --timestamp --identifier com.alexcatdad.usb-boop.dmg "${output}"
codesign --verify --strict "${output}"
echo "Signed disk image: ${output}"
echo 'Submit this DMG to notarytool, wait for Accepted, staple it, then calculate its checksum.'

#!/usr/bin/env bash

# Inspect only this distribution image, mounted read-only at a private path.
# Never launch the app or enumerate, mount, or detach USB/media devices.
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 || ! "$2" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
  echo "usage: $0 <release.dmg> <YYYY.MM.DD.N> [reference.zip]" >&2
  exit 1
fi

image="$1"
version="$2"
reference_archive="${3:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${image}" ]] || { echo "DMG does not exist: ${image}" >&2; exit 1; }
if [[ -n "${reference_archive}" && ! -f "${reference_archive}" ]]; then
  echo "Reference ZIP does not exist: ${reference_archive}" >&2
  exit 1
fi

verification_dir="$(mktemp -d)"
mount_dir="${verification_dir}/image"
attach_attempted=false
cleanup() {
  local result=$?
  trap - EXIT
  if [[ "${attach_attempted}" == true ]]; then
    # The unique mount point belongs to this invocation. Never detach by a
    # guessed disk number, volume name, or a path supplied by the caller.
    if ! hdiutil detach "${mount_dir}"; then
      echo "Could not detach verification image; preserving ${verification_dir}" >&2
      exit 1
    fi
  fi
  rm -rf "${verification_dir}"
  exit "${result}"
}
trap cleanup EXIT

hdiutil verify "${image}"
codesign --verify --strict \
  --test-requirement '=anchor apple generic and certificate leaf[subject.OU] = "CX6D6KGCT5"' \
  "${image}"
signature="$(codesign --display --verbose=4 "${image}" 2>&1)"
grep -q '^Authority=Developer ID Application:' <<< "${signature}"
grep -q '^Timestamp=' <<< "${signature}"
xcrun stapler validate "${image}"
spctl --assess --type open --context context:primary-signature --verbose=2 "${image}"

mkdir "${mount_dir}"
attach_attempted=true
hdiutil attach "${image}" -readonly -nobrowse -noautoopen -mountpoint "${mount_dir}" \
  > "${verification_dir}/attach.log"
app="${mount_dir}/usb-boop.app"
[[ -d "${app}" && ! -L "${app}" ]] || { echo "Expected app bundle missing from DMG" >&2; exit 1; }
[[ -L "${mount_dir}/Applications" && "$(readlink "${mount_dir}/Applications")" == '/Applications' ]] || {
  echo "Expected Applications link to /Applications" >&2
  exit 1
}

# Reuse the release verifier, including ZIP path checks, identity, version,
# architecture, entitlements, the app's own ticket, and execution assessment.
ditto -c -k --sequesterRsrc --keepParent "${app}" "${verification_dir}/contained-app.zip"
"${script_dir}/verify_release_artifact.sh" "${verification_dir}/contained-app.zip" "${version}"

if [[ -n "${reference_archive}" ]]; then
  "${script_dir}/verify_release_artifact.sh" "${reference_archive}" "${version}"
  mkdir "${verification_dir}/reference"
  ditto -x -k "${reference_archive}" "${verification_dir}/reference"
  reference_app="${verification_dir}/reference/usb-boop.app"
  diff -r "${reference_app}" "${app}"
  # BSD diff follows symlinks. Also compare their literal targets so changing
  # a framework link cannot pass merely because it resolves to identical bytes.
  python3 - "${reference_app}" "${app}" <<'PY'
import os
import sys

def links(root):
    result = {}
    for directory, directories, files in os.walk(root, followlinks=False):
        for name in directories + files:
            path = os.path.join(directory, name)
            if os.path.islink(path):
                result[os.path.relpath(path, root)] = os.readlink(path)
    return result

if links(sys.argv[1]) != links(sys.argv[2]):
    raise SystemExit('App symlinks differ from the reference ZIP')
PY
  echo "Contained app matches the reference ZIP without app content exclusions."
fi

echo "Verified signed and notarized DMG and contained app: ${version}"

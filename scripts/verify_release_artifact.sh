#!/usr/bin/env bash

# Read-only distribution checks on a fresh extraction. No signing credentials
# are needed, and neither the application nor any device is opened.
set -euo pipefail

if [[ $# -ne 2 || ! "$2" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
  echo "usage: $0 <release.zip> <YYYY.MM.DD.N>" >&2
  exit 1
fi

archive="$1"
version="$2"
verification_dir="$(mktemp -d)"
trap 'rm -rf "${verification_dir}"' EXIT

# Reject paths outside the expected bundle before extraction. ditto preserves
# the framework symlinks and stapled ticket required by Apple's verification.
python3 - "${archive}" <<'PY'
import posixpath
import stat
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    for entry in archive.infolist():
        path = entry.filename
        root = path.split('/')[0]
        if root not in ('usb-boop.app', '__MACOSX') or '..' in path.split('/'):
            raise SystemExit(f'Unexpected archive path: {path}')
        if stat.S_ISLNK(entry.external_attr >> 16):
            target = archive.read(entry).decode('utf-8')
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(path), target))
            if target.startswith('/') or resolved.split('/')[0] != root:
                raise SystemExit(f'Symlink escapes bundle: {path}')
PY

ditto -x -k "${archive}" "${verification_dir}"
app="${verification_dir}/usb-boop.app"
plist="${app}/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${plist}")" == 'com.alexcatdad.usb-boop' ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${plist}")" == "${version}" ]]
[[ "$(lipo -archs "${app}/Contents/MacOS/usb-boop")" == 'arm64' ]]

codesign --verify --deep --strict --all-architectures \
  --test-requirement '=anchor apple generic and certificate leaf[subject.OU] = "CX6D6KGCT5"' \
  "${app}"
signature="$(codesign --display --verbose=4 "${app}" 2>&1)"
grep -q '^Authority=Developer ID Application:' <<< "${signature}"
grep -q 'flags=.*(runtime)' <<< "${signature}"
grep -q '^Timestamp=' <<< "${signature}"
codesign --display --entitlements - --xml "${app}" > "${verification_dir}/entitlements.plist" 2>/dev/null
plutil -convert json -o - "${verification_dir}/entitlements.plist" | jq -e '
  . == {"com.apple.security.app-sandbox": true, "com.apple.security.device.usb": true}
' > /dev/null

xcrun stapler validate "${app}"
spctl --assess --type execute --verbose=2 "${app}"
echo "Verified Developer ID, Hardened Runtime, sandbox, USB entitlement, notarization, and Gatekeeper: ${version}"

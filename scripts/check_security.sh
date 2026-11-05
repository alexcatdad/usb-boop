#!/usr/bin/env bash
# Repository security invariants (see AGENTS.md): the App Sandbox and USB
# entitlements stay enabled and wired into both the Xcode build and the
# release signing script, and Hardened Runtime is not forced on in project.yml.

set -euo pipefail

entitlements="Sources/App/usb-boop.entitlements"
fail() { echo "security: $*" >&2; exit 1; }

for key in com.apple.security.app-sandbox com.apple.security.device.usb; do
  value="$(/usr/libexec/PlistBuddy -c "Print :${key}" "${entitlements}" 2>/dev/null)" \
    || fail "${entitlements} lacks ${key}"
  [[ "${value}" == "true" ]] || fail "${key} must be true in ${entitlements}"
done

grep -Eq "CODE_SIGN_ENTITLEMENTS: ${entitlements}\$" project.yml \
  || fail "project.yml must set CODE_SIGN_ENTITLEMENTS: ${entitlements}"
grep -Eq '^ *ENABLE_HARDENED_RUNTIME:' project.yml \
  && fail "project.yml must not set ENABLE_HARDENED_RUNTIME (breaks ad-hoc launches)"
# shellcheck disable=SC2016 # literal text in the script
grep -q -- '--entitlements "${entitlements}"' scripts/build_release_zip.sh \
  || fail "scripts/build_release_zip.sh must sign with MACOS_ENTITLEMENTS"

if command -v zizmor >/dev/null; then
  zizmor --persona regular .github/workflows
fi

echo "security: ok"

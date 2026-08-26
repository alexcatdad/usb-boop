#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "usage: $0 <tap-dir> <version> <sha256> <release-url>" >&2
  exit 1
fi

tap_dir="$1"
version="$2"
sha256="$3"
release_url="$4"

casks_dir="${tap_dir}/Casks"
cask_path="${casks_dir}/usb-boop.rb"

mkdir -p "${casks_dir}"

cat > "${cask_path}" <<EOF
cask "usb-boop" do
  version "${version}"
  sha256 "${sha256}"

  url "${release_url}",
      verified: "github.com/alexcatdad/usb-boop/"
  name "usb-boop"
  desc "Menu bar app that reports negotiated USB link speed"
  homepage "https://github.com/alexcatdad/usb-boop"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "usb-boop.app"

  # The app is ad-hoc signed rather than notarized, so Gatekeeper would
  # otherwise refuse to launch it. Remove this once Developer ID signing
  # and notarization are in place.
  postflight_steps do
    run "/usr/bin/xattr",
        args: ["-rd", "com.apple.quarantine", "{{appdir}}/usb-boop.app"]
  end

  # Kept alphabetical: brew style enforces Cask/ArrayAlphabetization.
  # The app is sandboxed, so its preferences live inside its container;
  # the loose plist is only left behind by pre-sandbox builds.
  zap trash: [
    "~/Library/Application Scripts/com.alexcatdad.usb-boop",
    "~/Library/Containers/com.alexcatdad.usb-boop",
    "~/Library/Preferences/com.alexcatdad.usb-boop.plist",
  ]
end
EOF

# Catch generation mistakes before they reach the tap.
if command -v ruby >/dev/null 2>&1; then
  ruby -c "${cask_path}" >/dev/null
fi

echo "cask_path=${cask_path}"

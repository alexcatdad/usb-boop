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

  url "${release_url}"
  name "usb-boop"
  desc "Native macOS menu bar app for USB connection speed detection"
  homepage "https://github.com/alexcatdad/usb-boop"
  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "usb-boop.app"

  # Remove quarantine flag since the app is ad-hoc signed, not notarized.
  # This will be removed once Developer ID signing is in place.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/usb-boop.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.alexcatdad.usb-boop.plist",
  ]
end
EOF

echo "cask_path=${cask_path}"

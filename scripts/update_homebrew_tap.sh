#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "usage: $0 [--linux] <tap-dir> <version> <sha256> <release-url>" >&2
  exit 1
fi

mode=cask
if [[ "$1" == "--linux" ]]; then
  mode=formula
  shift
fi
[[ $# == 4 ]] || { echo "Expected four arguments after optional --linux." >&2; exit 1; }
tap_dir="$1"
version="$2"
sha256="$3"
release_url="$4"

[[ "$version" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]] || [[ "$mode" == formula && "$version" == 0.0.0-dev ]] || { echo "Invalid version" >&2; exit 1; }
[[ "$sha256" =~ ^[0-9a-f]{64}$ ]] || { echo "Invalid SHA256" >&2; exit 1; }
[[ "$release_url" =~ ^https://github.com/alexcatdad/usb-boop/(archive/|releases/download/)[a-zA-Z0-9./_-]+$ ]] || { echo "Invalid source URL" >&2; exit 1; }

if [[ "$mode" == formula ]]; then
  mkdir -p "$tap_dir/Formula"
  cat > "$tap_dir/Formula/usb-boop.rb" <<EOF
class UsbBoop < Formula
  desc "Desktop app that reports negotiated USB link speed"
  homepage "https://github.com/alexcatdad/usb-boop"
  url "${release_url}"
  version "${version}"
  sha256 "${sha256}"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on :linux
  depends_on "qtbase"
  depends_on "qtwayland"
  depends_on "systemd"

  def install
    system "cmake", "-S", "linux", "-B", "build", "-G", "Ninja",
           "-DUSB_BOOP_VERSION=#{version}", "-DBUILD_TESTING=OFF", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  def caveats
    <<~EOS
      Start usb-boop from a terminal or your application launcher.
      If your desktop does not search Homebrew's share directory, add
      #{HOMEBREW_PREFIX}/share to XDG_DATA_DIRS before starting your session.
      GNOME may need an AppIndicator extension for tray access; the app also has a window.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/usb-boop --version")
    require "json"
    assert_kind_of Array, JSON.parse(shell_output("#{bin}/usb-boop --fixtures --list --json"))["devices"]
  end
end
EOF
  if command -v ruby >/dev/null 2>&1; then
    ruby -c "$tap_dir/Formula/usb-boop.rb" >/dev/null
  fi
  echo "formula_path=$tap_dir/Formula/usb-boop.rb"
  exit 0
fi

casks_dir="${tap_dir}/Casks"
cask_path="${casks_dir}/usb-boop.rb"

mkdir -p "${casks_dir}"

cat > "${cask_path}" <<EOF
cask "usb-boop" do
  version "${version}"
  sha256 "${sha256}"

  url "${release_url}"
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

#!/usr/bin/env bash
set -euo pipefail

# Package the approved artwork; never regenerate the design during a build.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
icon_source="$repo_dir/Design/nose-boop-source.png"
menu_source="$repo_dir/Design/nose-boop-menu-source.png"
icon_set="$repo_dir/Sources/App/Assets.xcassets/AppIcon.appiconset"
menu_set="$repo_dir/Sources/App/Assets.xcassets/MenuBarIcon.imageset"

for source in "$icon_source" "$menu_source"; do
  [[ -f "$source" ]] || { echo "Missing approved artwork: $source" >&2; exit 1; }
done
mkdir -p "$menu_set"

resize() {
  sips --resampleHeightWidth "$2" "$2" "$1" --out "$3" >/dev/null
}

for size in 16 32 128 256 512; do
  resize "$icon_source" "$size" "$icon_set/icon_${size}x${size}.png"
  resize "$icon_source" "$((size * 2))" "$icon_set/icon_${size}x${size}@2x.png"
done
resize "$icon_source" 512 "$repo_dir/docs/icon.png"
resize "$icon_source" 64 "$repo_dir/docs/favicon.png"
resize "$menu_source" 22 "$menu_set/nose-boop-menu.png"
resize "$menu_source" 44 "$menu_set/nose-boop-menu@2x.png"

echo "Packaged Nose Boop app, documentation, favicon, and menu-bar assets."

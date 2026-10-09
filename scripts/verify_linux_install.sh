#!/usr/bin/env bash
set -euo pipefail
version=$1
[[ $(usb-boop --version) == *"$version"* ]]
usb-boop --list --json | python3 -c 'import json,sys; assert isinstance(json.load(sys.stdin)["devices"],list)'
test -f /usr/share/applications/usb-boop.desktop
test -f /usr/share/icons/hicolor/256x256/apps/usb-boop.png
QT_QPA_PLATFORM=offscreen usb-boop --fixtures --smoke-test

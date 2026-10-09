#!/usr/bin/env bash
set -euo pipefail
binary=${1:-build/linux/src/usb-boop}
xvfb-run -a "$binary" --fixtures --smoke-test
runtime_dir=$(mktemp -d)
trap 'kill "${weston_pid:-}" 2>/dev/null || true; rm -rf "$runtime_dir"' EXIT
chmod 700 "$runtime_dir"
export XDG_RUNTIME_DIR="$runtime_dir"
weston --backend=headless-backend.so --socket=usb-boop-wayland --idle-time=0 > "$runtime_dir/weston.log" 2>&1 &
weston_pid=$!
for _ in {1..50}; do
  [[ -S "$runtime_dir/usb-boop-wayland" ]] && break
  sleep 0.1
done
[[ -S "$runtime_dir/usb-boop-wayland" ]] || { cat "$runtime_dir/weston.log"; exit 1; }
QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=usb-boop-wayland "$binary" --fixtures --smoke-test

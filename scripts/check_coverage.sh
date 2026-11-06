#!/usr/bin/env bash
# Fails when line coverage drops below the floors. Reads the result bundle that
# `task test` writes with `-enableCodeCoverage YES`.
#
# - USBBoopKit: the USBBoopKit.framework target.
# - App model: the Sources/App files compiled into USBBoopAppTests.
#
# Floors are the measured value rounded down, minus 2 (never below 60). Raise
# them when coverage grows; never lower them to make a change pass.

set -euo pipefail

KIT_FLOOR=87
APP_FLOOR=66

bundle="${1:?usage: check_coverage.sh <result bundle>}"

xcrun xccov view --report --json "${bundle}" |
  KIT_FLOOR="${KIT_FLOOR}" APP_FLOOR="${APP_FLOOR}" python3 -I -c '
import json, os, sys

report = json.load(sys.stdin)
targets = {t["name"]: t for t in report["targets"]}

def percent(files):
    covered = sum(f["coveredLines"] for f in files)
    executable = sum(f["executableLines"] for f in files)
    return 100.0 * covered / executable if executable else 0.0

def files_of(name, predicate=lambda f: True):
    target = targets.get(name)
    if target is None:
        sys.exit(f"coverage: target {name} missing from the report")
    return [f for f in target["files"] if predicate(f)]

checks = [
    ("USBBoopKit", percent(files_of("USBBoopKit.framework")), int(os.environ["KIT_FLOOR"])),
    ("App model", percent(files_of("USBBoopAppTests.xctest", lambda f: "/Sources/App/" in f["path"])),
     int(os.environ["APP_FLOOR"])),
]

failed = False
for label, value, floor in checks:
    status = "ok" if value >= floor else "BELOW FLOOR"
    print(f"coverage: {label} {value:.2f}% (floor {floor}%) {status}")
    failed |= value < floor
sys.exit(1 if failed else 0)
'

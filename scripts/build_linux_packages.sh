#!/usr/bin/env bash
set -euo pipefail
build_dir=${1:-build/linux}
version=${2:?usage: build_linux_packages.sh BUILD_DIR YYYY.MM.DD.N [DEB|RPM]}
generator=${3:-DEB}
[[ "$version" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]
[[ "$generator" == DEB || "$generator" == RPM ]]
cmake -S linux -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DUSB_BOOP_VERSION="$version"
cmake --build "$build_dir"
ctest --test-dir "$build_dir" --output-on-failure
(cd "$build_dir" && cpack -G "$generator")

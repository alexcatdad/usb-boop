#!/usr/bin/env bash

set -euo pipefail

git fetch --tags --force >/dev/null 2>&1 || true

existing_tag="$(
  git tag --points-at HEAD --list 'v[0-9]*' \
    | sed 's/^v//' \
    | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n \
    | tail -n 1 \
    | sed 's/^/v/' \
    || true
)"
if [[ -n "${existing_tag}" ]]; then
  echo "version=${existing_tag#v}"
  echo "tag=${existing_tag}"
  echo "created_new=false"
  exit 0
fi

today="$(date -u +%Y.%m.%d)"
latest_index="$(
  git tag -l "v${today}.*" \
    | sed -E "s/^v${today}\.([0-9]+)$/\1/" \
    | awk 'BEGIN { max = -1 } /^[0-9]+$/ { if ($1 > max) max = $1 } END { print max }'
)"

next_index=$((latest_index + 1))
version="${today}.${next_index}"

echo "version=${version}"
echo "tag=v${version}"
echo "created_new=true"

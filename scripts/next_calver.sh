#!/usr/bin/env bash

set -euo pipefail

# Published assets are immutable. Even repackaging the same source commit
# requires a new version. Fail on a stale tag inventory; never move local tags.
git fetch origin --tags >/dev/null

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

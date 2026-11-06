# shellcheck shell=bash
# Release version helpers, sourced by the release scripts.
#
# release-tools allocates daily CalVer `YYYY.MM.DD.N` (tag `vYYYY.MM.DD.N`) and
# passes the Apple bundle version `YYYY.MMDD.N` as MACOS_SHORT_VERSION and
# MACOS_BUNDLE_VERSION. Legacy `YYYY.M.N` releases map to themselves.

# Prints the Apple bundle version for a release version, or fails.
apple_version_for() {
  local version="$1"
  if [[ "${version}" =~ ^([0-9]{4})\.([0-9]{2})\.([0-9]{2})\.([1-9][0-9]*)$ ]]; then
    printf '%s.%d.%s\n' "${BASH_REMATCH[1]}" \
      "$((10#${BASH_REMATCH[2]} * 100 + 10#${BASH_REMATCH[3]}))" "${BASH_REMATCH[4]}"
  elif [[ "${version}" =~ ^[0-9]{4}\.[0-9]{1,2}\.[1-9][0-9]*$ ]]; then
    printf '%s\n' "${version}"
  else
    return 1
  fi
}

# Succeeds for an Apple bundle version: three integers, YYYY.MMDD.N or legacy YYYY.M.N.
is_apple_version() {
  [[ "$1" =~ ^[0-9]{4}\.[0-9]{1,4}\.[1-9][0-9]*$ ]]
}

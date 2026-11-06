# Release Automation

## Release ownership

Releases are explicit and local. Nothing in GitHub Actions builds, signs,
publishes, tags or updates the Homebrew tap, and no workflow dispatches a
release. The Developer ID private key and the notarization profile stay in the
macOS Keychain on the maintainer's Mac and are named in a local release-tools
config outside the checkout (`~/.config/release-tools/config.json`, see
release-tools `docs/consumer.md`). Machine-specific names are never committed.

[`release.json`](../release.json) declares the targets and signing; the
[`Taskfile.yml`](../Taskfile.yml) pins `reltool` (release-tools, by tag and commit)
and exposes the entry points. Run them from a clean, reviewed commit. The first
run builds `reltool` from a release-tools checkout, by default
`../../../infrastructure/release-tools` (the `alexcatdad/infrastructure` layout);
set `RELTOOL_SRC=<path>` when it lives elsewhere:

```sh
task release:check     # read-only; prints the commit and the next version
task release:prepare   # build, sign, notarize, staple; nothing is published
task release           # prepare, then draft release, SHA-256 verification,
                       # publish, and the Homebrew cask update
task release:resume    # continue an unfinished release (same version/artifacts)
task release:abandon VERSION   # before publication only
```

`task release` does not wait for or read GitHub check status. After merging a
reviewed commit and confirming CI independently, run `release:check` first.
Signing and automated verification do not replace manual hardware, notification,
accessibility, or login testing.

## Versions and release assets

Versions use daily CalVer `YYYY.MM.DD.N`: the UTC date and a per-day counter
starting at 1; tags are `vYYYY.MM.DD.N`. reltool allocates the version and passes
it as `RELEASE_VERSION`, with the Apple bundle version `YYYY.MMDD.N` (for example
`2026.1105.1` for `2026.11.05.1`) as `MACOS_SHORT_VERSION`
(`CFBundleShortVersionString`) and `MACOS_BUNDLE_VERSION` (`CFBundleVersion`).
`scripts/build_release_zip.sh` builds with those two values, and
`scripts/verify_release_artifact.sh` checks both against the release version
(`scripts/release_version.sh` holds the mapping). Older `YYYY.M.N` versions map to
themselves; the next daily version sorts above the last tag, `v2026.09.17.5`.

Published versions are append-only: do not move a published tag or replace an
asset. A changed signature, stapled ticket, binary, or replacement packaging
requires a new version.

Each release contains:

- `usb-boop-macos-arm64.zip`, containing `usb-boop.app` for Apple
  Silicon (macOS 14 or later), Developer ID signed, notarized and stapled;
- `SHA256SUMS` and `usb-boop-<version>.manifest.json`, written by reltool.

The DMG installer (`scripts/build_release_dmg.sh`) is not part of the automated
release yet: its contained app must be notarized before the DMG is built, which
the build-then-notarize order of `release:prepare` does not provide. The scripts
are kept; see the [DMG runbook](development-runbook.md#dmg-installer).

The checksum is calculated after notarization and stapling. Install checks for
the produced zip: `validate:darwin-arm64` verifies identity, version,
architecture, Developer ID, Hardened Runtime and entitlements before
notarization; reltool then verifies, notarizes and staples, and `release`
publishes via a draft release.

## Signing and verification

`scripts/build_release_zip.sh` performs the Release build and signs nested code
before the containing app, using `MACOS_SIGNING_IDENTITY` and
`MACOS_ENTITLEMENTS` supplied by reltool to the signed target's build task. The
published app must retain the App Sandbox and USB entitlement and use the
release bundle identifier `com.alexcatdad.usb-boop`.

```sh
./scripts/verify_release_artifact.sh usb-boop-macos-arm64.zip 2026.10.1
```

It verifies the packaged app's version and bundle identity, Developer ID team
`CX6D6KGCT5`, signatures, Hardened Runtime, sandbox, stapled notarization ticket,
and Gatekeeper acceptance. It does not inspect USB devices or media contents.

## Platforms

Only macOS arm64 is released. The Linux app (pull request #17) and its tap
package are not merged; Linux targets are added to `release.json` when that
lands. They would need the Fedora worker (`runs: worker`) or cross-compilation.

## GitHub workflows

- [validation.yml](../.github/workflows/validation.yml) calls
  `alexcatdad/ci-actions` (secret scan, dependency review, `task lint`,
  `task build`; on `main` `task test` and `task security`; CodeQL for Swift) on
  pull requests, `main`, and a weekly schedule, and lints the generated
  Homebrew cask (`task cask:lint`).
- [pages.yml](../.github/workflows/pages.yml) publishes the documentation site.

There is no release workflow. The tap is updated by the local release task from
the published, verified release.

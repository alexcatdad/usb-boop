# Release Automation

## Release ownership

Release packages are built and signed on Alex's Mac. The Developer ID private key
stays in the macOS Keychain; GitHub Actions receives neither that key nor Apple
notarization credentials. Notarization still submits the signed package to Apple.

Merging to `main` runs tests and security checks but does not publish an app.
After checks pass on the reviewed release commit, the local release process:

1. selects a new CalVer version and builds that exact clean commit;
2. signs the framework and app with Developer ID and Hardened Runtime;
3. submits the archive to Apple and waits for an **Accepted** result;
4. staples Apple's ticket to the app, repackages it, and verifies the final zip;
5. tags the source commit and publishes the zip and its SHA-256 sidecar;
6. lets GitHub verify the published package before updating Homebrew.

See the [development runbook](development-runbook.md) for the local commands and
acceptance record. Signing and automated verification do not replace manual
hardware, notification, accessibility, or login testing.

## Versions and release assets

Versions use `YYYY.MM.DD.N`, with the date in UTC and `N` starting at `0` each
day. `scripts/next_calver.sh` proposes the next version using existing tags.
For example, `2026.09.17.4` is tagged as `v2026.09.17.4`.

Published versions are append-only: do not move a published tag, replace an
archive, or overwrite its checksum. A changed signature, stapled ticket, binary,
or replacement packaging requires a new version. This preserves existing downloads and
Homebrew's checksum expectations. In particular, converting an earlier ad-hoc
release to Developer ID signing requires a new version.

A new download format may be added to an existing release when its contained
app matches the existing signed/stapled ZIP exactly. Do not replace any existing
asset, checksum, or tag. Record the packaging source and separate DMG notarization
receipt; run release verification after adding the files. This lets us offer a
DMG for `2026.09.17.4` without rebuilding or re-signing its already approved app.

Each stable release contains:

- `usb-boop-macos-arm64.zip`, containing `usb-boop.app` for Apple Silicon;
- `usb-boop-macos-arm64.sha256`, containing the final archive's checksum.

The manual download also offers `usb-boop-macos-arm64.dmg` and
`usb-boop-macos-arm64.dmg.sha256`. Its Nose Boop window contains the app and an
Applications link. The DMG itself is Developer ID signed, notarized, and stapled;
the contained app retains its own existing signature and ticket. Homebrew
continues using the ZIP. See the [DMG runbook](development-runbook.md#dmg-installer).

The checksum is calculated **after** stapling and repackaging. Publishing is the
last local step, after validation succeeds. A draft release can hold the assets
while preparing the release; the Homebrew workflow runs only after publication.

## Signing and verification

`scripts/build_release_zip.sh <version> <output-dir>` performs the Release build
and signs nested code before the containing app. Set `CODESIGN_IDENTITY` to the
local Developer ID Application identity. The published app must retain the App
Sandbox and USB entitlement and use the release bundle identifier
`com.alexcatdad.usb-boop`.

The release verifier is shared between local acceptance and GitHub:

```sh
./scripts/verify_release_artifact.sh dist/usb-boop-macos-arm64.zip 2026.09.17.4
```

It verifies the packaged app's version and bundle identity, Developer ID team
`CX6D6KGCT5`, signatures, Hardened Runtime, sandbox, stapled notarization ticket,
and Gatekeeper acceptance. It does not inspect USB devices or media contents.

An earlier notarization acceptance applies only to the submitted build. Every
new release archive must complete its own signing, notarization, stapling, and
verification sequence.

## GitHub workflows

- [ci.yml](../.github/workflows/ci.yml) builds, tests, lints, and validates the
  generated Homebrew cask on pull requests and `main`.
- [security.yml](../.github/workflows/security.yml) checks workflow supply chain,
  workflow/shell correctness, and Swift code on pull requests, `main`, and a
  weekly schedule.
- [release.yml](../.github/workflows/release.yml) reacts to a published release.
  It downloads and verifies the existing package on macOS, then updates the
  Homebrew tap on Ubuntu. It never builds or signs the app.

The Release workflow can also be dispatched manually with an existing published
release tag to recover a failed Homebrew delivery. It accepts only a non-draft,
non-prerelease CalVer tag that resolves to a commit in `main` history and is the
latest stable GitHub release.

Release delivery runs are serialized. Before writing the tap, the workflow
checks the latest release again and refuses a lower version than the current
cask. The Ubuntu job downloads the archive again and requires the exact checksum
verified by the macOS job, so a changed asset cannot silently bypass verification.
A tap push conflict fails rather than overwriting concurrent work; inspect and
rerun delivery after resolving the conflict.

All external actions are pinned to full commit SHAs. Dependabot proposes updates.
Workflow permissions start empty; release verification only reads repository
contents. Checkout credentials are disabled except for the deliberate tap push.
Release tags and other dynamic values are passed through environment variables,
not interpolated into shell programs.

## Required credentials

On the release Mac:

- the Developer ID Application identity and private key in Keychain;
- a Keychain notarization profile, currently `usb-boop-notary`;
- GitHub CLI authorization to create tags and publish release assets.

Do not export the Apple private key or store notarization credentials in GitHub.

The Homebrew update job continues using the `action-runners` environment:

- variable `APP_ID`;
- secret `APP_SECRET`, the GitHub App private key with write access to
  `alexcatdad/homebrew-tap`.

That GitHub App credential is independent of Apple signing. Its installation
token is scoped to the tap and contents write permission. `GITHUB_TOKEN` reads
published release metadata/assets; it does not publish or create tags.

## Homebrew delivery

`scripts/update_homebrew_tap.sh` generates `Casks/usb-boop.rb`. The cask uses
`depends_on macos: :sonoma`, Apple Silicon architecture, GitHub latest-release
livecheck, and sandbox-container paths for `zap`. It does not strip quarantine:
Gatekeeper evaluates the Developer ID signature and notarization ticket.

CI regenerates the cask, runs `brew style --cask`, and loads it with
`HOMEBREW_DEVELOPER=1 brew info --cask` to catch deprecated DSL behavior.

```sh
brew tap alexcatdad/tap
brew install --cask alexcatdad/tap/usb-boop
```

## Security checks and provenance

The project has no third-party Swift runtime dependencies. Its automated checks
cover application code and the CI configuration:

| Check | Tool | Purpose |
|-------|------|---------|
| Workflow supply chain | zizmor | Credential persistence, unsafe interpolation, excessive permissions, unpinned actions |
| Workflow correctness | actionlint | Workflow syntax, expressions, and contexts |
| Shell scripts | shellcheck | Shell quoting and correctness |
| Application code | CodeQL Swift | Security and quality queries |
| Action versions | Dependabot | Pinned action updates |
| Published app | macOS signature, notarization, and Gatekeeper tools | Expected developer identity and accepted distributable package |
| Download integrity | SHA-256 | Match published bytes to the package verified on macOS |

Locally built packages do **not** carry a GitHub Actions build-provenance
attestation. A workflow that merely downloads an app must not claim it built
that app. Developer ID identifies the signing developer, and Apple's
notarization records its assessment; neither proves that the binary was built
from a particular Git commit. Building from the clean reviewed commit and
recording the source, toolchain, notarization submission, and final checksum in
the release evidence remain the maintainer's responsibility.

Earlier ad-hoc releases may retain their historical CI attestations. Those
attestations describe those earlier archives only and are not evidence for a
new locally signed release.

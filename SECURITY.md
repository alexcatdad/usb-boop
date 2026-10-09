# Security Policy

## Reporting a Vulnerability

Report vulnerabilities privately through GitHub's
[security advisory form](https://github.com/alexcatdad/usb-boop/security/advisories/new).
Please do not open a public issue for a suspected vulnerability.

Expect an initial response within seven days.

## Supported Versions

Only the latest release is supported. Versions follow CalVer
(`YYYY.MM.DD.N`); fixes ship as a new release rather than as patches to an
older one.

## What This App Does

The macOS app runs sandboxed and:

- reads USB device metadata through IOKit, using the
  `com.apple.security.device.usb` entitlement
- stores its settings in its own sandbox container
- posts local user notifications

The Linux app runs as an ordinary user. It reads cached USB metadata from sysfs
and listens for udev events; it never opens device nodes, mounts storage, claims
interfaces, or performs device I/O. It stores preferences in user settings,
delivers notifications over the session D-Bus, and creates an XDG autostart entry
only when enabled. It dynamically links Qt and libudev and does not install a
system daemon or host udev rules.

Neither app makes network requests or has **telemetry, analytics, or tracking**.
The macOS app has no third-party Swift dependencies. Any change to those properties should
be treated as a security-relevant change.

## Release Trust

Starting with `2026.09.17.4`, macOS releases are Developer ID signed locally and
notarized by Apple. The private key and notarization credentials remain in the
maintainer's local Keychain. GitHub Actions receives only public artifacts and
verifies the expected team, bundle identity, version, Hardened Runtime,
sandbox/USB entitlements, stapled ticket, and Gatekeeper acceptance before
updating Homebrew. The cask does not remove quarantine.

These locally built packages do not claim GitHub build provenance. Signing
establishes the publisher and detects changes to signed code; notarization is
Apple's malware check, not proof that the app has no bugs. The maintainer must
build the reviewed commit from a clean checkout after CI passes.

Releases through `2026.09.17.3` were ad-hoc signed CI builds with GitHub
attestations. Their existing assets remain unchanged. Use the latest signed
release; do not bypass Gatekeeper to install an older build.

You can also build from source or check the `usb-boop-macos-arm64.sha256`
published with each release. Checksums detect corruption; they do not replace
the Developer ID signature or notarization.

Linux packages have architecture-specific checksums and installation checks.
The Linux Homebrew formula builds an immutable, checksummed source archive.
These Linux artifacts do not use Apple signing or notarization. The initial
`0.0.0-dev` formula is an unreleased preview pinned to the implementation commit.

## Automated Checks

Every pull request runs zizmor, actionlint, shellcheck, and CodeQL; the same
checks run weekly against `main`. All GitHub Actions are pinned to full commit
SHAs and updated by Dependabot. See
[docs/release-automation.md](docs/release-automation.md) for details.

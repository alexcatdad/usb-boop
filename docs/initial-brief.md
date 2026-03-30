# usb-boop Initial Brief

## Product Summary

`usb-boop` should be a tiny native macOS utility that sits in the menu bar, watches for USB attach events, and shows an immediate human-readable notification with the connected device name and negotiated speed.

The core value is speed and trust:

- no manual System Information digging
- no polling if the platform gives us a reliable event stream
- simple language first, raw technical detail second
- offline-first, local-only behavior

## Recommended Technical Direction

### App architecture

- Native Swift macOS app
- SwiftUI for settings and optional detail surfaces
- AppKit-backed menu bar integration via `NSStatusItem`
- `UserNotifications` for system notifications
- `SMAppService` for launch-at-login support

### Device monitoring

- Use IOKit / IORegistry notifications for attach and detach observation
- Resolve device metadata from the relevant USB service node
- Normalize raw speed and protocol signals into a small internal enum
- Apply a heuristics layer so the UI can say "10 Gbps" when that is more trustworthy than over-specific USB branding

### Persistence

- Start with lightweight local persistence for recent events and device aliases
- Prefer a simple file-backed store first unless the app shape clearly benefits from SwiftData

### Distribution

- Release signed app archives through GitHub Releases
- Install through Homebrew as a cask
- Use GitHub Actions for CI and release automation

## Early Assumptions

These are the assumptions I would use for the first scaffold unless you want to steer them differently:

- Minimum target: macOS 14+
- Apple Silicon only
- Unsandboxed direct distribution, not a Mac App Store build
- Attach notifications enabled by default
- Detach notifications disabled by default
- Advanced inspector stays inside the same app, not a separate companion tool
- Cable Test Mode lands after the first functional MVP
- No recent-history persistence in MVP
- No launch-at-login in MVP
- App name remains `usb-boop`

## Locked Decisions

These decisions were confirmed during scaffolding:

- macOS 14+ minimum target
- Apple Silicon only
- direct distribution outside the Mac App Store
- no Developer ID signing or notarization planned
- Homebrew installation will use an existing custom tap
- MVP is connect notifications plus a companion menu showing currently connected devices
- no persistent history in MVP
- no launch-at-login in MVP

## Notification Reality Check

The app can send local macOS notifications, but it cannot fully control whether the system presents them as transient banners or persistent alerts. Notification Center owns that user-facing style.

The practical MVP answer is:

- usb-boop sends the connect notification
- the app keeps the latest result visible in the menu companion when the user enables the pinned-result toggle

## Constraints That Matter Early

### Homebrew delivery

For a GUI macOS app, the realistic path is a Homebrew cask backed by GitHub Releases. Trying to go straight into `homebrew-cask` or `homebrew-core` would add overhead too early.

### Signing and notarization

If the app is unsigned, installation is still possible but rougher for end users because of Gatekeeper. If you want a cleaner Homebrew install story, we should decide early whether you want Developer ID signing and notarization in the release pipeline.

### USB data quality

We should expect some devices, hubs, and composite peripherals to expose incomplete or noisy metadata. The product should prefer "speed unavailable" over overclaiming.

## Remaining Clarifications

These are the only decisions still useful before release automation is finished:

1. What is the exact Homebrew tap repository we should target for release formula or cask updates?
2. How much raw debug detail should the first visible inspector surface when speed detection is ambiguous?

## Proposed Scaffold Sequence

Once the answers above are settled, the scaffold should probably happen in this order:

1. Xcode-based native macOS app project
2. Menu bar shell with settings window
3. USB event monitoring service with fixture mode for development
4. Notification pipeline and current-device model
5. Preferences for notification behavior
6. GitHub Actions CI for build and test
7. Release packaging for Homebrew cask installation

## Success Bar For The First Working Milestone

The first milestone should let us plug in a common USB device and see a notification in under one second that includes:

- device name
- negotiated speed label
- enough recent history to compare repeated tests

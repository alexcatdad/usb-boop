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

- Minimum target: recent supported macOS version on Apple Silicon first
- Intel support is nice-to-have, not a launch blocker
- Unsandboxed direct distribution, not a Mac App Store build
- Attach notifications enabled by default
- Detach notifications disabled by default
- Advanced inspector stays inside the same app, not a separate companion tool
- Cable Test Mode lands after the first functional MVP

## Constraints That Matter Early

### Homebrew delivery

For a GUI macOS app, the realistic path is a Homebrew cask backed by GitHub Releases. Trying to go straight into `homebrew-cask` or `homebrew-core` would add overhead too early.

### Signing and notarization

If the app is unsigned, installation is still possible but rougher for end users because of Gatekeeper. If you want a cleaner Homebrew install story, we should decide early whether you want Developer ID signing and notarization in the release pipeline.

### USB data quality

We should expect some devices, hubs, and composite peripherals to expose incomplete or noisy metadata. The product should prefer "speed unavailable" over overclaiming.

## Clarifications Before App Scaffolding

These are the questions that will most influence the first project scaffold:

1. What minimum macOS version do you want to support for v1?
2. Do you want to target Apple Silicon only for the first release, or ship universal binaries from day one?
3. Are you okay with direct distribution outside the Mac App Store, including an unsandboxed app if the USB APIs need it?
4. Do you want us to plan for Developer ID signing and notarization now, or leave that for a later release pass?
5. For Homebrew, is a custom tap such as `alexcatdad/tap` acceptable for the first public release?
6. Should the first scaffold include only connect notifications and recent history, or do you want Cable Test Mode represented in the initial architecture now?
7. Do you want recent event history to persist across launches in v1, or can it be in-memory until the first functional milestone lands?
8. Should the app start at login in the MVP, or can that wait until after basic detection is working?
9. How much raw debug detail do you want visible in v1 when speed detection is ambiguous?
10. Do you want us to commit to a specific app name now, or keep `usb-boop` as the public package and repository name while the menu bar title remains flexible?

## Proposed Scaffold Sequence

Once the answers above are settled, the scaffold should probably happen in this order:

1. Xcode-based native macOS app project
2. Menu bar shell with settings window
3. USB event monitoring service with mocked fallback fixtures for development
4. Notification pipeline and recent-history model
5. Local persistence and preferences
6. GitHub Actions CI for build and test
7. Release packaging for Homebrew cask installation

## Success Bar For The First Working Milestone

The first milestone should let us plug in a common USB device and see a notification in under one second that includes:

- device name
- negotiated speed label
- enough recent history to compare repeated tests

# usb-boop

`usb-boop` is a native macOS menu bar app that detects newly attached USB devices and immediately tells you how fast they actually connected.

The goal is simple: make cable, hub, and port testing faster than digging through System Information.

## Planned Product Shape

- Native macOS menu bar app
- Real-time USB attach detection
- Local notification on connect with device name and negotiated speed
- Short recent-history menu
- Offline-first, local-only behavior

## Planned Tech Direction

- Swift
- SwiftUI for settings and detail surfaces
- AppKit for menu bar integration
- IOKit / IORegistry access for USB attach notifications and device metadata
- UserNotifications for system notifications

## Installation Goal

The app is intended to be installed via Homebrew cask from `alexcatdad/tap`.

## Current MVP Scope

- Menu bar-only macOS app
- Native SwiftUI companion window via `MenuBarExtra`
- Current connected USB device list
- Local notification on connect with device name and negotiated speed
- No persistent history in MVP
- No launch-at-login in MVP

## Build Locally

1. Install XcodeGen: `brew install xcodegen`
2. Generate the project: `xcodegen generate`
3. Open the project: `open usb-boop.xcodeproj`

You can also run tests from the command line:

```sh
xcodegen generate
xcodebuild -project usb-boop.xcodeproj -scheme usb-boop -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test
```

## Release Model

- Pushes to `main` produce a CalVer release
- Release tags use `vYYYY.MM.DD.N`
- GitHub Actions packages the app and updates the Homebrew cask in `alexcatdad/homebrew-tap`

Release details live in [release-automation.md](/Users/alex/REPOS/alexcatdad/usb-boop/docs/release-automation.md).

## Repository Status

This repository is in active scaffolding. The initial product brief and decision log live in [docs/initial-brief.md](/Users/alex/REPOS/alexcatdad/usb-boop/docs/initial-brief.md).

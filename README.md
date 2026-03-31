<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="usb-boop icon">
</p>

<h1 align="center">usb-boop</h1>

<p align="center">
  A native macOS menu bar app that detects USB devices the moment they connect<br>and tells you the negotiated link speed — instantly.
</p>

<p align="center">
  <a href="https://github.com/alexcatdad/usb-boop/releases/latest"><img src="https://img.shields.io/github/v/release/alexcatdad/usb-boop?style=flat-square&label=latest" alt="Latest Release"></a>
  <a href="https://github.com/alexcatdad/usb-boop/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/alexcatdad/usb-boop/ci.yml?style=flat-square&label=CI" alt="CI Status"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/arch-Apple%20Silicon-blue?style=flat-square" alt="Apple Silicon">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/alexcatdad/usb-boop?style=flat-square" alt="MIT License"></a>
</p>

---

## Why

Plugging in a USB device and wondering *"did it actually connect at full speed?"* shouldn't require digging through System Information. usb-boop lives in your menu bar, watches IOKit for attach events, and fires a notification with the device name and negotiated speed in under a second.

Perfect for testing cables, hubs, and ports.

## Install

### Homebrew (recommended)

```sh
brew tap alexcatdad/tap
brew install --cask alexcatdad/tap/usb-boop
```

### Manual

Download the latest `usb-boop-macos-arm64.zip` from [Releases](https://github.com/alexcatdad/usb-boop/releases/latest), unzip, and drag to Applications.

> The app is currently unsigned. On first launch you may need to right-click and choose Open, or run `xattr -rd com.apple.quarantine /Applications/usb-boop.app`.

## What it does

- Lives in the menu bar with zero dock presence
- Detects USB device connections in real time via IOKit
- Shows a native macOS notification with device name and link speed
- Displays all currently connected USB devices in a companion window
- Persists your notification and display preferences

### Speeds it recognizes

| Label | Speed | Standard |
|-------|-------|----------|
| USB 1.x Low | 1.5 Mbps | USB 1.0 |
| USB 1.x Full | 12 Mbps | USB 1.1 |
| USB 2.0 High | 480 Mbps | USB 2.0 |
| USB 3.2 Gen 1 | 5 Gbps | USB 3.0 / 3.1 Gen 1 |
| USB 3.2 Gen 2 | 10 Gbps | USB 3.1 Gen 2 |
| USB 3.2 Gen 2x2 | 20 Gbps | USB 3.2 |

## Build from source

Requires Xcode 16+ and Apple Silicon.

```sh
brew install xcodegen
xcodegen generate
open usb-boop.xcodeproj
```

Run tests from the command line:

```sh
xcodegen generate
xcodebuild -project usb-boop.xcodeproj -scheme usb-boop \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO test
```

### Development mode

Set `USB_BOOP_USE_FIXTURES=1` in the Xcode scheme environment to run with simulated devices (no hardware needed). This is only available in Debug builds.

## Architecture

```
Sources/
  App/                    SwiftUI app, menu bar, settings
    AppModel.swift        Observable state, monitor + notification orchestration
    MenuBarContentView    Companion window with device list
    SettingsView          Preferences
  USBBoopKit/             Reusable framework
    IOKitUSBMonitor       Real USB monitoring via IOKit
    FixtureUSBMonitor     Mock monitor for development
    USBDevice             Device model
    USBConnectionSpeed    Speed enum with display labels
    UserNotificationCoordinator  macOS notification handling
Tests/
  USBBoopKitTests/        Framework unit + integration tests
  USBBoopAppTests/        App model tests
```

## Release model

Releases follow [CalVer](https://calver.org/) (`YYYY.MM.DD.N`). Every push to `main` that isn't a docs/ci/chore commit triggers a release via GitHub Actions, which:

1. Tags the commit
2. Builds and zips the `.app` bundle
3. Creates a GitHub Release with the artifact and SHA256 checksum
4. Updates the Homebrew cask in [`alexcatdad/homebrew-tap`](https://github.com/alexcatdad/homebrew-tap)

## License

[MIT](LICENSE)

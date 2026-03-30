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

The app is intended to be installed via Homebrew once release packaging is in place.

## Repository Status

This repository is currently in discovery and scaffolding. The initial product brief and open questions live in [docs/initial-brief.md](/Users/alex/REPOS/alexcatdad/usb-boop/docs/initial-brief.md).

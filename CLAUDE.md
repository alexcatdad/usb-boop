# CLAUDE.md — Development Rules for usb-boop

## Project

Native macOS menu bar app (Swift 6, macOS 14+, Apple Silicon). Detects USB device connections via IOKit and shows negotiated link speed.

## Build

```sh
brew install xcodegen swiftlint
xcodegen generate
xcodebuild -project usb-boop.xcodeproj -scheme usb-boop \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test
```

## Architecture

- `Sources/USBBoopKit/` — reusable framework: USB monitoring, device model, notifications
- `Sources/App/` — SwiftUI app: menu bar UI, settings, app model
- `Tests/USBBoopKitTests/` — framework tests (unit + IOKit integration)
- `Tests/USBBoopAppTests/` — app model tests (compiles App sources directly, excludes @main)

## Rules

### Swift

- Swift 6 strict concurrency. All `@MainActor` isolation must be explicit.
- Never use `@unchecked Sendable` without a comment explaining why it is safe.
- Never use `force_unwrapping` (`!`) outside of tests.
- Run `swiftlint` before committing. CI enforces zero warnings.

### Testing

- All new logic must have tests. Target: 85%+ on testable code.
- Use `FixtureUSBMonitor` and `MockNotificationCenter` for unit tests, not real system APIs.
- IOKit integration tests are acceptable but must not assert on specific device counts (CI runners vary).
- `@MainActor` on test classes that touch MainActor-isolated types.

### Git

- Branch from `main`, PR back to `main`. No direct pushes.
- CI must pass before merge. Squash-merge PRs.
- Commit messages: conventional commits (`feat:`, `fix:`, `test:`, `docs:`, `ci:`, `chore:`).
- Commits prefixed `docs:`, `ci:`, `chore:`, `test:`, or `style:` skip the release pipeline.

### UI

- Follow Apple HIG for macOS menu bar apps.
- All interactive elements must have VoiceOver labels.
- Speed values must be the visually prominent element in device rows.
- No developer scaffolding in user-facing UI (no "MVP", "Planned later", etc.).

### App Store

- App Sandbox must remain enabled. USB access via `com.apple.security.device.usb`.
- Hardened Runtime must remain enabled.
- `PrivacyInfo.xcprivacy` must be kept current with any new API usage.
- Never add tracking, analytics, or network calls.

### Dependencies

- Zero third-party Swift dependencies. Keep it that way.
- SwiftLint and XcodeGen are build-time only tools, not linked into the app.

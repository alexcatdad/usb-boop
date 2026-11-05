# usb-boop

## Purpose

Detects USB device connections via IOKit and shows the negotiated link speed,
for anyone who wants to know whether a cable or port is running at full speed.
Native macOS menu-bar app (Swift 6, macOS 14+, Apple Silicon). macOS only, for
good; pure Swift, no backend.

## Invariants

- App Sandbox stays enabled. USB access only through
  `com.apple.security.device.usb`. The entitlements are wired through
  `CODE_SIGN_ENTITLEMENTS` in `project.yml` **and** the `MACOS_ENTITLEMENTS`
  that reltool passes to `codesign` in `scripts/build_release_zip.sh`; the
  release build signs the bundle itself, so dropping either one silently ships
  an unsandboxed app. `task security` checks both.
- Hardened Runtime is applied at signing time, only when the signing identity is
  a real Developer ID. Never set `ENABLE_HARDENED_RUNTIME` in `project.yml`: it
  enables library validation, which an ad-hoc signature cannot satisfy for the
  embedded `USBBoopKit.framework`, and the app then fails to launch.
- No network calls, telemetry, analytics or tracking.
- Keep `PrivacyInfo.xcprivacy` current with any new API usage.
- No third-party dependencies. First-party `alexcatdad/menubar-kit` is allowed,
  pinned by revision (`.revision("<full sha>")`; four-part CalVer tags don't
  resolve in SwiftPM). SwiftLint and XcodeGen are build-time tools only. The DMG
  layout uses hash-pinned `ds-store` and `mac-alias` in an isolated Python
  environment; packaging tools never ship inside the app or installer.

### Swift

- Swift 6 strict concurrency. All `@MainActor` isolation is explicit.
- Never use `@unchecked Sendable` without a comment explaining why it is safe.
- No force unwrapping (`!`) outside tests.
- `swiftlint --strict` must pass with zero warnings.

### Testing

- All new logic has tests. Target 85%+ on testable code.
- Unit tests use `FixtureUSBMonitor` and `MockNotificationCenter`, not real
  system APIs.
- IOKit integration tests are fine but must not assert on specific device counts
  (machines vary).
- Mark test classes `@MainActor` when they touch MainActor-isolated types.

### UI

- Follow Apple HIG for macOS menu-bar apps.
- Every interactive element has a VoiceOver label.
- Speed values are the visually prominent element in device rows.
- No developer scaffolding in user-facing UI ("MVP", "Planned later", …).

## Layout

- `Sources/USBBoopKit/` — framework: USB monitoring, device model, notifications.
- `Sources/App/` — SwiftUI app: menu-bar UI, settings, app model, entitlements.
- `Tests/USBBoopKitTests/` — framework tests (unit + IOKit integration).
- `Tests/USBBoopAppTests/` — app model tests (compiles App sources directly, excludes `@main`).
- `project.yml` — XcodeGen spec; `usb-boop.xcodeproj` is generated from it.
- `scripts/` — release build, verification, DMG and cask scripts.
- `docs/` — site, release and development runbooks. User-facing product truth lives in `README.md`.

## Build & verify

```sh
brew install go-task xcodegen swiftlint
task check
```

- `task check` — the full local gate: lint, build, tests, security checks. CI runs the same tasks.
- `task lint`, `task build`, `task test`, `task security` — what CI calls
  (`alexcatdad/ci-actions` validate-pr/validate-main). `task lint` also runs
  actionlint and shellcheck when installed.
- `task cask:lint` — generates the cask with `scripts/update_homebrew_tap.sh`
  and runs `brew style`/`brew info` on it in a throwaway tap. CI runs it too.
- Toolchain: Swift 6 on Xcode for macOS 26 (CI selects Xcode 26.6 on `macos-26`), Task, XcodeGen, SwiftLint.

## Release

- Local only, with release-tools (`task release:check`, `task release:prepare`,
  `task release`); see `docs/release-automation.md`. Developer ID signed,
  notarized and stapled; keys and notarization credentials stay in the local
  Keychain. CI never builds, signs, publishes or updates the tap.
- Release target `darwin-arm64` (`build:darwin-arm64`, `validate:darwin-arm64`).
- Versions are CalVer `vYYYY.MM.DD.N`. Releases are immutable: never replace
  published assets or move tags.
- Distribution: Homebrew cask `usb-boop` in `alexcatdad/homebrew-tap`; the tap
  entry must pass `brew style --cask`. Never strip quarantine: signed, notarized
  releases pass Gatekeeper normally.

## Git

- Canonical host: GitHub `alexcatdad/usb-boop`.
- Branch from `main`, PR back to `main`, squash-merge. Conventional commit
  messages (`feat:`, `fix:`, `test:`, `docs:`, `ci:`, `chore:`).
- Required checks: `pr / leaks`, `pr / lint`, `pr / build`, `pr / deps`, `codeql`. Copilot reviews every PR.
- Actions are pinned to full commit SHAs with a trailing `# vX.Y.Z` comment;
  workflows start from `permissions: {}` and check out with
  `persist-credentials: false`. Never interpolate untrusted input into `run:`;
  pass it via `env:`.
- Do not wait on or poll CI; one status check when a decision depends on it.

## Memory

Decisions, constraints and project state live in Scratchpad (project
`usb-boop`), not in repo files. Read context there before substantial work and
record meaningful decisions there.

`decisions.jsonl` is legacy: it moves to the Scratchpad MCP and is deleted once
imported. The service is down as of 2026-11-05, so the file stays until then;
don't add new entries to it.

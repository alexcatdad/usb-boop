# Resume development

## Inspect before changing code

```sh
git status --short --branch
git fetch origin
git log HEAD..origin/main --oneline
gh pr list
gh issue list
gh run list --workflow ci.yml -L 3
gh run list --workflow release.yml -L 3
```

Review incoming commits and preserve local files before updating the checkout.
Create a `codex/` branch for implementation and deliver through a PR.

## Toolchain and verification

Full Xcode is required; Command Line Tools alone cannot run this project.
If Xcode is installed outside the default location, set `DEVELOPER_DIR` to its
`Contents/Developer` directory for the shell running these commands.

```sh
xcodebuild -version
xcodegen generate
swiftlint lint --strict
xcodebuild -project usb-boop.xcodeproj -scheme usb-boop \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test
```

Open `usb-boop.xcodeproj` and run the app. Use `USB_BOOP_USE_FIXTURES=1` in
the Debug scheme environment for simulated devices. Then disable fixtures and
verify real attach/detach events, negotiated speed against System Information,
notification permissions, hub filtering, and persisted settings. Passing unit
tests does not establish real hardware or notification delivery acceptance.

## 2026-09-17 inspection

- Local main: `a9c19fa`; fetched origin/main: `c330be4` (two commits ahead).
- Subsequently fast-forwarded main to `c330be4` at the user's request; local main
  now matches origin/main.
- Incoming commits update installation docs and sandbox/release configuration.
- Existing untracked `.claude/` directory preserved; no application code changed.
- XcodeGen and SwiftLint are installed. Active developer directory is Command
  Line Tools. `xcodebuild` cannot run; SwiftLint crashes loading SourceKit.
- Installed app exists at `/Applications/usb-boop.app`; UI and hardware behavior
  have not been verified in this inspection.
- Investigate monitor lifecycle: `stop()` releases resources but does not reset
  `started`, so a subsequent `start()` returns without registering callbacks.
- Investigate notification preference behavior: startup requests permission even
  when notifications are disabled, and permission status refresh is startup-only.

## Toolchain restored

After installing and selecting Xcode, `xcodebuild -version` reports Xcode 27.0
(27A266a). Project generation succeeds without tracked project changes, strict
SwiftLint passes, and the documented unsigned macOS test command succeeds.
Test log: `/tmp/usb-boop-resume-tests.log` (temporary local evidence).
Manual UI, real device reconnects, and notification delivery still need checking.

## Inspect Homebrew compatibility

```sh
brew --version
brew config
HOMEBREW_NO_AUTO_UPDATE=1 brew info --cask alexcatdad/tap/usb-boop
HOMEBREW_NO_AUTO_UPDATE=1 brew style --cask alexcatdad/tap/usb-boop
HOMEBREW_NO_AUTO_UPDATE=1 brew livecheck --cask alexcatdad/tap/usb-boop
```

Compare the generator with the remote `Casks/usb-boop.rb` in
`alexcatdad/homebrew-tap` and the official Homebrew migration guide.
Style may bootstrap Homebrew's Ruby tooling. A fully qualified install even
with `--dry-run` can record cask trust; do not treat it as a read-only check.

2026-09-17: Homebrew `7.0.1-25-gaba1167`; published and installed cask version
`2026.08.26.0`. Info and livecheck warn that `url verified:` is deprecated.
Style passes despite this warning; livecheck finds no newer app release.
The install dry-run succeeded and reported trusting the cask; no reinstall
was performed. Style bootstrapped its Ruby dependencies. The generator and tap
need the same future removal of `verified:`. No implementation changes made.

References: https://brew.sh/7.0.0-migration-guide/ and
https://docs.brew.sh/Tap-Trust .

## Homebrew fix validation

Removed `url verified:` in the generator and tap. Strict developer-mode cask
loading fails for the original and passes for the corrected cask. Style passes,
generator and tap output match exactly, and actionlint and shellcheck pass.
The disposable validation tap and its scoped trust were removed afterward.

## Monitoring reliability acceptance

Registry access is metadata-only: no device opens, volume mounts, file-transfer
reads or writes, elevation, or filesystem permission requests. Missing metadata
is unknown; only explicit OS denial is access restricted. Retry is user-driven.

Run the standard lint/build/test commands above after project generation.
Tests inject registration failures, denied and partial snapshots, reconnects,
restart, and wake reconciliation. Startup devices have first-seen timestamps,
not invented connection times. Inspect the sandboxed release separately:

1. Launch without opening the menu; confirm metadata enumeration and no startup alerts.
2. Compare displayed link speed with System Information for available hardware.
3. Connect a hub and read-only/inaccessible/unmounted storage, without opening
   files or trying to determine volume access by probing it.
4. Unplug/replug and sleep/wake; verify accurate state and no alert storms.
5. Trigger a failed metadata read through the fixture tests; verify stale or
   partial results are labelled and Retry is explicit.

Physical reconnect, sleep/wake, read-only/inaccessible media checks remain
unverified until performed on suitable hardware. Automated tests are separate
from device acceptance.

PR1 local validation: full Xcode tests, strict SwiftLint, actionlint, and
shellcheck passed. Evidence: `/tmp/usb-boop-pr1-final.log`. No physical media
access tests, logout, or sleep were performed.

## Everyday usability acceptance

New installations default to notifications and sound off. Existing notification
preferences remain intact, but startup never prompts. Enable is an explicit
user action. Denied permission shows System Settings guidance rather than
repeated requests. Grouping uses a fixed one-second window; detach, disable,
stop, or unreliable monitoring cancels affected queued/in-flight banners.

History holds at most 50 serial-free observations in memory. Hiding hubs also
filters history. Startup enumeration does not create history. Launch at login
uses actual ServiceManagement status and only changes on explicit interaction.
Debug bundle ID is `com.alexcatdad.usb-boop.dev`; Release retains its existing ID.

Automated tests cover startup permissions, denial, permission changes, grouping,
cancellation while authorization is suspended, monitor restart, history limits,
privacy, login errors/pending approval and read-only refresh. A rendered menu
check uses 30 devices and a long name to verify the 390-point width and bounded
height. Optional render artifact (after building tests):

```sh
USB_BOOP_RENDER_ARTIFACTS=/tmp \
DYLD_FRAMEWORK_PATH=/tmp/usb-boop-pr2-derived/Build/Products/Debug \
xcrun xctest -XCTest USBBoopAppTests.MenuLayoutTests \
  /tmp/usb-boop-pr2-derived/Build/Products/Debug/USBBoopAppTests.xctest
```

Local release packaging passed using `scripts/build_release_zip.sh`, including
ad-hoc signature verification and sandbox entitlements. Artifact/log evidence:
`/tmp/usb-boop-release-artifacts`, `/tmp/usb-boop-release-build.log`, and
`/tmp/usb-boop-pr2-final.log`. This is not notarization or hardware acceptance.

Still unverified: physical read-only/inaccessible media, rapid unplug/replug,
sleep/wake, interactive notification delivery/denial, VoiceOver and keyboard
navigation, and actual logout/login with the installed release. Native UI
selection timed out through the available computer-use tool; static rendered
layout was inspected instead. Do not log out the user's session to test startup.

### Sandboxed metadata probe result

A temporary helper app linked against the exact Release USBBoopKit framework,
ad-hoc signed with the app's existing sandbox and USB entitlements, enumerated
14 real devices and stopped cleanly. No initial device had a connectedAt time.
Its speed counts matched `system_profiler SPUSBHostDataType -json` on macOS 27:
5 at 12 Mbps, 5 at 480 Mbps, 1 at 5 Gbps, and 3 at 10 Gbps. Only counts were
reported; no serials were exported and no volume contents were accessed. On older macOS,
check `system_profiler -listDataTypes` for the supported USB report name.
This proves sandboxed metadata enumeration, not physical reconnect, restricted
media, sleep/wake, notification visibility, or login-session acceptance.

## Menu window and Settings regression (2026-09-17)

Native screenshots exposed a MenuBarExtra sizing failure: the outer ScrollView
used only a maximum height, allowing the live menu to collapse to roughly 149
points overall. Give that viewport an explicit 520-point height; the device list
retains its 320-point cap and controls remain outside the scrolling region.
The layout test must reject menus that are too short as well as too tall. It
checks `NSHostingController.sizeThatFits` with a zero-height proposal, since
the ideal fitting size alone failed to reproduce the native window's collapse.
Restoring the old maximum-only frame makes that assertion fail at 121 points
against the 600-point minimum; the fixed frame passes.

Settings now explicitly activates the application and invokes SwiftUI's public
`openSettings` action. Menu-bar interaction alone does not guarantee activation.
Keep the native Settings scene; do not search private SwiftUI window identifiers
or introduce delayed activation guesses.

Local verification: strict SwiftLint and all 122 tests pass. Native before/after
screenshots in the development conversation show the full corrected menu and
successful scrolling to the final device while controls remain visible. The
Settings button opened the window, and Alex confirmed it appeared in front.
This does not establish notification permission or login-item acceptance.

To build a sandboxed local Debug app independently of the installed release:

```sh
xcodebuild -project usb-boop.xcodeproj -scheme usb-boop -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/usb-boop-menu-fix-derived CODE_SIGNING_ALLOWED=NO build
debug_app=/tmp/usb-boop-menu-fix-derived/Build/Products/Debug/usb-boop-dev.app
codesign --force --sign - "$debug_app/Contents/Frameworks/USBBoopKit.framework/Versions/A"
codesign --force --sign - --entitlements Sources/App/usb-boop.entitlements "$debug_app"
codesign --verify --deep --strict "$debug_app"
open "$debug_app"
```

Open the menu manually before attaching a native UI inspector: this accessory
app may be unselectable by inspection tools when it has no visible windows.

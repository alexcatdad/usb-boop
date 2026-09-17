# Resume development

## Notification permission debugging (2026-09-17)

In the sandboxed ad-hoc Debug app, clicking Enable notifications reached
`UNUserNotificationCenter.requestAuthorization` but returned immediately with an
`UNErrorDomain` code 1: "Notifications are not allowed for this application."
The original UI discarded its localized description. No permission dialog
appeared; this was distinct from a user declining a displayed prompt.

Expose the returned error in the menu and Settings, log only its domain/code,
and show an in-progress message while preventing duplicate Enable requests.
Pending state must be cleared on stop and protected from an older request's
completion after restart. A passive refresh that still reports not-determined
must preserve the last request error. Startup/activation refresh without prompting.

Moving the identical ad-hoc-signed diagnostic app from
`/tmp/usb-boop-notifications-derived/Build/Products/Debug/usb-boop-dev.app` to
`~/Applications/usb-boop-dev.app` resolved authorization. Alex confirmed it
worked, and native Settings inspection showed "Connection notifications are
enabled." Neither its code/signature nor its sandbox/USB entitlements changed
for this comparison. Use the stable Applications location for local interactive
acceptance; do not launch the temporary build directly. This establishes the
location-dependent failure on this host, not a universal rule for every macOS
version. Inspect only this app's diagnostic logs when troubleshooting:

```sh
/usr/bin/log show --last 5m --style compact \
  --predicate 'process == "usb-boop-dev" AND subsystem == "com.alexcatdad.usb-boop"'
```

Do not clear system notification preferences, reset permission databases, or
add push-notification entitlements to debug local banners. Native authorization is verified. Alex subsequently observed a connection banner
and reported that its title/subtitle/body hierarchy was too verbose.
The inspector times out while the app has only its menu-bar item and no open window.

Local strict SwiftLint and all 126 tests pass, covering error detail, passive
refresh, explicit retry, duplicate actions, and restart handling. Logs:
`/tmp/usb-boop-notifications-lint.log` and
`/tmp/usb-boop-notifications-tests.log`. This is not a release or notarization run.

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
installed_debug_app="$HOME/Applications/usb-boop-dev.app"
mkdir -p "$HOME/Applications"
# Quit an existing Debug instance before replacing its bundle.
ditto "$debug_app" "$installed_debug_app"
codesign --verify --deep --strict "$installed_debug_app"
open "$installed_debug_app"
```

Open the menu manually before attaching a native UI inspector: this accessory
app may be unselectable by inspection tools when it has no visible windows.
The temporary build directory is suitable for compilation, but notification
acceptance on this host requires launching the copy in `~/Applications`.


## Concise connection banners (2026-09-17)

Single-device banners put the device name in the title and
`Connected · Link speed: 10 Gbps` in the body. Leave the subtitle empty; technical
USB generation labels remain available in the menu. Unknown speeds retain the
explicit unavailable label. Grouped banners put the count in the title and use
`Open usb-boop for link speeds.` as the body. Sound remains off by default.

Updated existing content assertions, strict SwiftLint, and all 126 tests pass.
The rebuilt, sandboxed Debug app was copied to `~/Applications/usb-boop-dev.app`
and relaunched. The next real connection should verify the revised banner's
native appearance; the test suite verifies its payload, not on-screen delivery.
Logs: `/tmp/usb-boop-notification-copy-lint.log` and
`/tmp/usb-boop-notification-copy-tests.log`.

The initial Boop and Fast Loop icon proposals were superseded by the selected
cat-themed Nose Boop identity below.


## Nose Boop identity (2026-09-17)

Alex selected Nose Boop as the lasting identity: a ginger cat boops a teal USB-C
plug, and the app reports the connection's link speed. The canonical references
are [the branding guide](branding.md), `Design/nose-boop-source.png`, and
`Design/nose-boop-menu-source.png`. The earlier SVG icon was removed so future
exports cannot accidentally restore the retired design.

Regenerate every packaged image from the approved masters:

```sh
./scripts/generate_icon_assets.sh
shellcheck scripts/generate_icon_assets.sh
```

The script uses macOS `sips` to resize the approved artwork, without changing the
design. It updates all ten AppIcon sizes, the 1x/2x monochrome MenuBarIcon assets,
README/site `docs/icon.png`, and `docs/favicon.png`. The menu-bar catalog marks
its image as a template; `USBBoopApp` loads it instead of the generic cable symbol.
Notifications inherit the app's compiled icon rather than attaching extra artwork.
Keep the existing accessible menu-bar name, `usb-boop`.

Validation: all asset dimensions checked; repeat generation produced identical
hashes; full tests (126), strict SwiftLint, and ShellCheck passed. Browser previews
verified the full-color artwork at 256/64/32/16 pixels, the 22-point menu mark on
light/dark backgrounds, and the local website hero. The rebuilt sandboxed Debug
bundle was installed in `~/Applications/usb-boop-dev.app`, registered with
LaunchServices, and relaunched. Its installed AppIcon.icns hash matches the
built bundle. No permission/cache database was reset. A subsequent native banner
with the new icon remains a manual acceptance check.

Logs: `/tmp/usb-boop-nose-boop-lint.log` and
`/tmp/usb-boop-nose-boop-tests.log`. Publication follows the repository's main-branch workflows. Alex subsequently
authorized merging PR #12; verify every check on its current head before the
squash merge. This approval supersedes the earlier instruction to keep it in draft.

Alex found the first detailed menu-bar mark hard to recognize. It was simplified
to a cat-head silhouette, then given a bold transparent USB-trident cutout at
Alex's request. The final mark was previewed at 22 points in light/dark appearances.
The full-color Nose Boop artwork is unchanged. Menu dismissal behavior is being
clarified separately; no speculative menu lifecycle change was made.


## PR #12 delivery authorization (2026-09-17)

Alex explicitly requested merging to main after the local notification and
Nose Boop work. Mark the PR ready, review current-head checks and findings, and
squash-merge only when all checks pass. Main pushes trigger the existing release
workflow. The earlier accepted notarization applies only to its submitted build;
it does not notarize subsequent CI artifacts. Report merge, publication, and
notarization as separate outcomes. Menu-dismissal clarification and a native
banner with the final icon remain manual acceptance follow-ups.

## Local signed release

Alex authorized local Developer ID signing and publication of the current app
on 2026-09-17. Keep the Apple private key and notarization profile in Keychain.
The already published `2026.09.17.3` archive remains unchanged; the first signed
release is planned as `2026.09.17.4`. This is a packaging/distribution change,
with no additional USB or filesystem access by the app.

Merge the delivery workflow through a PR after all checks pass on its exact
head. Source must be clean and on the reviewed `main` commit. Record the full
commit, Xcode version, submission ID, final checksum, and verification results
in the GitHub release notes. Do not export keys or put passwords in arguments.

```sh
git switch main
git pull --ff-only origin main
git status --porcelain
git rev-parse HEAD
xcodebuild -version
security find-identity -v -p codesigning
./scripts/next_calver.sh
```

Use the proposed version below; ensure `git status --porcelain` is empty and
the release tag does not already exist. Build artifacts stay outside the repo:

```sh
release_version=2026.09.17.4
release_root="/tmp/usb-boop-local-release-${release_version}"
mkdir -p "$release_root/submission" "$release_root/final"
CODESIGN_IDENTITY='Developer ID Application: Alexandru Alexandrescu (CX6D6KGCT5)' \
DERIVED_DATA_PATH="$release_root/DerivedData" \
  ./scripts/build_release_zip.sh "$release_version" "$release_root/submission" \
  > "$release_root/build.log" 2>&1
git diff --exit-code
xcrun notarytool submit "$release_root/submission/usb-boop-macos-arm64.zip" \
  --keychain-profile usb-boop-notary --output-format json \
  > "$release_root/submission.json"
submission_id=$(jq -r .id "$release_root/submission.json")
xcrun notarytool info "$submission_id" --keychain-profile usb-boop-notary \
  --output-format json > "$release_root/status.json"
```

Submit once. If pending, query the same ID later; do not repeatedly upload.
If interrupted, recover the ID from `submission.json` or `notarytool history`.
Only continue after `status.json` says `Accepted`. Inspect Apple's log:

```sh
jq -e '.status == "Accepted"' "$release_root/status.json"
xcrun notarytool log "$submission_id" --keychain-profile usb-boop-notary \
  "$release_root/notary-log.json"
signed_app="$release_root/DerivedData/Build/Products/Release/usb-boop.app"
xcrun stapler staple "$signed_app"
ditto -c -k --sequesterRsrc --keepParent "$signed_app" \
  "$release_root/final/usb-boop-macos-arm64.zip"
(cd "$release_root/final" && shasum -a 256 usb-boop-macos-arm64.zip \
  > usb-boop-macos-arm64.sha256)
./scripts/verify_release_artifact.sh \
  "$release_root/final/usb-boop-macos-arm64.zip" "$release_version"
```

The verifier checks a fresh extraction with no quarantine bypass and does not
launch the app or access devices. Keep manual hardware/UI acceptance separate.
After verification, create an annotated tag at the recorded source commit,
upload the two final files to a draft release, download and verify them again,
then publish. Never use `--clobber`, replace a published file, or force a tag.

```sh
release_tag="v${release_version}"
git tag -a "$release_tag" -m "Release $release_tag: locally signed and notarized"
git push origin "refs/tags/$release_tag"
# Write release-notes.md with source, toolchain, submission ID, checksum,
# validation, and any remaining manual acceptance limitations first.
gh release create "$release_tag" "$release_root/final/usb-boop-macos-arm64.zip" \
  "$release_root/final/usb-boop-macos-arm64.sha256" --verify-tag --draft \
  --title "$release_tag" --notes-file "$release_root/release-notes.md"
gh release download "$release_tag" --dir "$release_root/download" \
  --pattern usb-boop-macos-arm64.zip --pattern usb-boop-macos-arm64.sha256
(cd "$release_root/download" && shasum -a 256 -c usb-boop-macos-arm64.sha256)
./scripts/verify_release_artifact.sh \
  "$release_root/download/usb-boop-macos-arm64.zip" "$release_version"
gh release edit "$release_tag" --draft=false --latest
gh run list --workflow release.yml -L 3
```

Wait for both release verification and Homebrew delivery to pass. Read the
remote tap cask and verify version, URL, SHA, and absence of quarantine removal.
Do not install over the user's release app or change Debug preferences just to
test publishing. The release workflow can be retried with `gh workflow run
release.yml -f tag="$release_tag"` after diagnosing a failure.

Local gate acceptance: the earlier notarized `2026.09.17.1` artifact passes
the new verifier (identity, exact entitlements, architecture, ticket, and
Gatekeeper). This proves the verifier accepts a real Apple-approved package;
the new release still needs its own submission and recorded evidence.

Pre-merge validation for this delivery change: strict SwiftLint, ShellCheck,
actionlint, regular zizmor, and whitespace checks passed. The verifier rejected
a real ad-hoc `.3` release, a modified executable, a mismatched version, path
traversal, and an escaping symlink. Missing signing identity failed before any
build/output creation. Independent review found no blockers; full application
tests and CodeQL remain required on the PR head before squash merge.

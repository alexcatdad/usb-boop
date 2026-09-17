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

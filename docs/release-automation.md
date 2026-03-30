# Release Automation

## Overview

`usb-boop` now follows the same release shape as `paw-proxy`: release automation runs directly on `push` to `main` and on manual `v*` tag pushes.

The release flow does five things:

1. derives a CalVer version in the form `YYYY.MM.DD.N`
2. tags the commit as `vYYYY.MM.DD.N`
3. skips non-release commit types such as `docs:`, `ci:`, `chore:`, `test:`, and `style:`
4. builds and uploads a zipped Apple Silicon `.app` bundle to GitHub Releases
5. updates the Homebrew tap cask in `alexcatdad/homebrew-tap`

## CalVer Rules

- version format: `YYYY.MM.DD.N`
- date source: UTC
- `N` starts at `0` each day
- additional releases on the same UTC day increment `N`

Examples:

- `2026.03.30.0`
- `2026.03.30.1`
- `2026.03.31.0`

## Workflows

- [ci.yml](/Users/alex/REPOS/alexcatdad/usb-boop/.github/workflows/ci.yml)
  Runs build and tests on pull requests and pushes to `main`.
- [release.yml](/Users/alex/REPOS/alexcatdad/usb-boop/.github/workflows/release.yml)
  Runs on direct `main` pushes and `v*` tag pushes, creates the release, and updates the Homebrew tap.

## Required Secrets And Variables

To match `paw-proxy`, the tap update job expects the same GitHub App-based setup:

- repository or environment variable: `APP_ID`
- repository or environment secret: `APP_SECRET`
  The private key for the GitHub App that can write to `alexcatdad/homebrew-tap`

`GITHUB_TOKEN` is used for the tag and release in the `usb-boop` repo itself.

## Release Artifact

The published asset is:

- `usb-boop-macos-arm64.zip`

It contains the unsigned `usb-boop.app` bundle built for Apple Silicon only.

## Homebrew Delivery

The workflow updates the Homebrew tap as a cask because `usb-boop` is a GUI macOS app.

Generated cask path:

- `Casks/usb-boop.rb`

Expected install command after the first release lands:

```sh
brew tap alexcatdad/tap
brew install --cask alexcatdad/tap/usb-boop
```

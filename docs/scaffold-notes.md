# Scaffold Notes

## What Exists Today

- XcodeGen project spec at `project.yml`
- native macOS menu bar app shell
- `USBBoopKit` framework target for USB models, monitoring, and notifications
- fixture mode for UI development via `USB_BOOP_USE_FIXTURES=1`
- GitHub Actions workflow for project generation and tests

## Why The Project Uses XcodeGen

The repository stays more readable when the project definition is source-controlled as YAML instead of committing only a generated `.pbxproj`.

The intended workflow is:

1. edit `project.yml`
2. run `xcodegen generate`
3. build or test

## Known Gaps After Scaffolding

- USB metadata extraction is intentionally narrow in the first pass and may need refinement once real hardware is tested
- system notification persistence is controlled by macOS, so the app uses a pinned latest-result card in the menu companion as the app-managed sticky surface
- Homebrew release automation still needs the exact tap target

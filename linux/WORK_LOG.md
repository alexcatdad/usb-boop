# Linux implementation checklist

- [x] Approved plan: separate C++20/Qt 6 app; Mac sources unchanged.
- [x] Branch created: codex/linux-support.
- [x] Toolchain ready (GCC 16.2, Qt 6.11.2, CMake/Ninja through Homebrew; sudo unavailable).
- [x] USB backend and deterministic tests.
- [x] Desktop feature parity and deterministic tests.
- [x] DEB/RPM packaging and clean x86_64 installation verification.
- [x] Linux x86_64/ARM64 native CI and Mac regression CI pass on reviewed application commit 598b69e.
- [x] Homebrew formula, generator and native source install CI pass on both architectures.
- [x] Independent review and repairs.
- [x] Both PRs opened, attached and cross-linked (app #17, tap #5).
- [ ] Final exact-commit CI passes.

## Validation evidence

Physical ARM64 hardware and physical hotplug are not implied by fixture or CI tests.
Record commands, results and remaining environmental limitations here.

- Local Debug build succeeds with GCC 16.2 / Qt 6.11.2, dynamically linked.
- Integrated CTest: backend, desktop, isolated D-Bus notifications and headless CLI suites pass.
- Live `--list --json` reads eight USB devices as an ordinary user with reliable status;
  serial numbers are absent from output. No USB device nodes are opened.
- Mac app/Xcode/source tests remain byte-for-byte unchanged (`git diff --exit-code`
  over Sources, Tests, project.yml and usb-boop.xcodeproj).
- Existing four-argument tap generator produces a byte-identical Mac cask compared
  with the baseline script for the same version/checksum/URL.
- Qt offscreen preview inspected for populated/latest/history layout. Actual GNOME/KDE,
  physical hotplug/resume and physical ARM64 hardware have not been validated.
- Clean Ubuntu 24.04 (GCC 13 / Qt 6.4.2) and Fedora 44 (GCC 16 / Qt 6.11.2)
  builds, tests and runtime-only DEB/RPM installs pass on x86_64 via Podman.
- Ubuntu Xvfb/X11 and Weston/headless Wayland fixture startup checks pass.
- Local address/undefined-behavior sanitizer build and all four suites pass.
- Reviewed commit `598b69eae07c445cce2869edecbb83825651ca46` passes native Linux
  build/test/DEB/RPM clean installation and X11/Wayland checks on both architectures,
  Homebrew source install/style/audit/tests on both architectures, Mac app tests,
  SwiftLint, cask validation, C++ CodeQL, sanitizer tests, formatting, workflow lint
  and zizmor. Swift CodeQL remains pending at this implementation-stage checkpoint.
  Final exact-commit results are maintained in the linked PRs:
  https://github.com/alexcatdad/usb-boop/pull/17 and
  https://github.com/alexcatdad/homebrew-tap/pull/5.
- Independent review repaired resume event replay, same-instance metadata recovery,
  denied-access retries, notification delivery recovery and platform delivery gates.
- Final release-verifier review requires exact version equality, rejecting a
  package whose version merely contains the expected version as a substring.
- Desktop follow-up: launched the app on this machine's KDE/Wayland session and
  confirmed its StatusNotifierItem registration. The desktop portal reports dark
  mode; after the theme-aware tray fix, the registered pixmap's 167 opaque artwork
  pixels are white. Regression coverage checks dark/light portal changes, nested
  settings replies, palette fallback, unknown preferences and alpha preservation.
  This evidence validates KDE tray registration and exported pixels; physical
  hotplug/resume, GNOME and physical ARM64 validation remain unavailable.

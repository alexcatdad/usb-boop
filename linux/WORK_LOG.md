# Linux implementation checklist

- [x] Approved plan: separate C++20/Qt 6 app; Mac sources unchanged.
- [x] Branch created: codex/linux-support.
- [x] Toolchain ready (GCC 16.2, Qt 6.11.2, CMake/Ninja through Homebrew; sudo unavailable).
- [x] USB backend and deterministic tests.
- [x] Desktop feature parity and deterministic tests.
- [x] DEB/RPM packaging and clean x86_64 installation verification.
- [ ] Linux x86_64/ARM64 final CI, Mac regression CI, security checks.
- [x] Homebrew formula, generator and tap CI implemented (native install CI pending).
- [x] Independent review and repairs.
- [x] Both PRs opened and attached (app #17, tap #5; final cross-links pending).
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
- Initial PR CI passes Mac app tests, cask validation, C++ CodeQL, sanitizer tests,
  formatting and zizmor. An inline shellcheck filename-handling finding is repaired.
  Final exact-commit checks remain pending; inspect app #17 and tap #5 for evidence.
- Independent review repaired resume event replay, same-instance metadata recovery,
  denied-access retries, notification delivery recovery and platform delivery gates.

# Linux implementation checklist

- [x] Approved plan: separate C++20/Qt 6 app; Mac sources unchanged.
- [x] Branch created: codex/linux-support.
- [x] Toolchain ready (GCC 16.2, Qt 6.11.2, CMake/Ninja through Homebrew; sudo unavailable).
- [x] USB backend and deterministic tests.
- [x] Desktop feature parity and deterministic tests.
- [ ] DEB/RPM packaging and installation verification.
- [ ] Linux x86_64/ARM64 CI, Mac regression CI, security checks.
- [ ] Homebrew formula, generator and tap CI.
- [ ] Independent review and repairs.
- [ ] Both PRs opened, attached and cross-linked.
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
- Clean Ubuntu/Fedora package builds and installation checks in progress via Podman.

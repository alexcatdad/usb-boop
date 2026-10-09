# Linux development and validation

The Linux app is a separate C++20/Qt 6 implementation. The Swift app and Xcode
project remain native macOS code. Both apps report negotiated USB link speed,
not measured file-transfer throughput.

## Build

Ubuntu 24.04:

```sh
sudo apt-get install build-essential cmake ninja-build qt6-base-dev qt6-wayland libudev-dev
```

Fedora 44:

```sh
sudo dnf install gcc-c++ cmake ninja-build qt6-qtbase-devel qt6-qtwayland systemd-devel
```

Homebrew:

```sh
brew install gcc cmake ninja qtbase qtwayland systemd pkgconf
cmake -S linux -B build/linux -G Ninja \
  -DCMAKE_PREFIX_PATH="$(brew --prefix qtbase)" \
  -DCMAKE_BUILD_TYPE=Debug
```

For non-Homebrew compilers set `CMAKE_CXX_COMPILER` explicitly if needed. Ensure
pkg-config can locate the Homebrew systemd `libudev.pc` when using that toolchain.

```sh
cmake --build build/linux
QT_QPA_PLATFORM=offscreen ctest --test-dir build/linux --output-on-failure
build/linux/src/usb-boop --version
build/linux/src/usb-boop --fixtures --list --json
build/linux/src/usb-boop --list --json
build/linux/src/usb-boop --fixtures
```

`--list --json` uses a headless application and never requires a display server.
It returns a device snapshot, a status message and a reliability flag, and omits
serial numbers. An incomplete or failed live snapshot exits unsuccessfully;
an empty reliable snapshot is valid. `--fixtures` explicitly selects simulated
devices. `--smoke-test --fixtures` opens the UI briefly and exits for display
server smoke checks.

## Desktop integration

Qt selects X11 or Wayland from the session; install the matching platform plugin.
The app connects to the existing user session's D-Bus notification service and
the host's login service for suspend/resume. Installing dependencies does not
replace or start the host's system manager.

GNOME installations without an indicator extension may have no tray host. The
normal application window stays available in that case. Notification sound is
subject to notification-server capabilities and desktop quiet-hours settings.
Autostart is opt-in, belongs to the logged-in user, and is not a system service.

Homebrew installs desktop entries and icons below its share prefix. If that
directory is absent from `XDG_DATA_DIRS`, add it to your desktop session's data
search path, or copy the installed desktop entry to `~/.local/share/applications`.
Use the formula's installation caveats for its stable executable path. The GUI
requires a graphical Linux session; headless enumeration also works on servers.

## Dependencies and licenses

Application code and existing mascot artwork retain the repository MIT license.
Qt is dynamically linked using its open-source licensing terms (LGPL/GPL, with
commercial licensing also available). libudev is part of systemd and uses LGPL
terms. Distributions supply runtime libraries; packages must declare their
dependencies rather than embed private static copies. Build/test tools do not
ship as application code. No tracking or application network calls are added.

## Evidence and limits

CI uses native x86_64 and ARM64 runners. Fixtures verify speed mapping, connection
identity, races, failures, history, notifications and presentation without relying
on hardware counts. Xvfb and headless Wayland smoke checks verify application
startup; they are not physical GNOME/KDE or hardware compatibility certification.

Real-device validation should exercise: initial enumeration without banners,
plug/unplug, a hub with multiple devices, cable-induced speed changes, and
suspend/resume without replayed alerts. Test as an ordinary user. Do not grant
USB write permissions to make a metadata read succeed. Record unavailable metadata
as unavailable rather than diagnosing a faulty cable.

Record actual checks in `linux/WORK_LOG.md`; do not infer physical ARM64 hardware
validation from native CI builds or fabricate checks requiring unavailable hardware.

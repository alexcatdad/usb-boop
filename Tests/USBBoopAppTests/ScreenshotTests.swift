import AppKit
import MenubarKit
import SwiftUI
import XCTest

@testable import USBBoopKit

/// Website screenshots from fixture data. Every run renders the panels and
/// Settings offscreen with MenubarKit's `PanelSnapshot`; with
/// `USB_BOOP_SCREENSHOTS=<dir>` (`TEST_RUNNER_USB_BOOP_SCREENSHOTS` through
/// xcodebuild, see `task screenshots`) the PNGs are also written there.
@MainActor
final class ScreenshotTests: XCTestCase {
    /// A believable, generic desk: one device per speed colour.
    private static let devices = [
        USBDevice(id: 1, name: "Portable SSD", speed: .usb3Gen2, connectedAt: at(9, 41)),
        USBDevice(id: 2, name: "2.5 Gigabit Ethernet Adapter", speed: .usb3Gen1, firstSeenAt: at(8, 55)),
        USBDevice(id: 3, name: "USB Audio Interface", speed: .usb2High, connectedAt: at(9, 20)),
        USBDevice(id: 4, name: "Wired Keyboard", speed: .usb1Full, firstSeenAt: at(8, 55)),
    ]

    private static let appearances: [(name: NSAppearance.Name, suffix: String)] = [
        (.aqua, "light"), (.darkAqua, "dark"),
    ]

    func test_panelScreenshots() throws {
        for appearance in Self.appearances {
            let (model, _) = try makeModel()
            model.keepLatestResultPinned = false
            let png = try render(MenuBarContentView(model: model, bundle: try fixtureBundle()), appearance.name)
            try write(png, "panel-\(appearance.suffix).png")
        }
    }

    func test_panelActivityScreenshots() throws {
        for appearance in Self.appearances {
            let (model, monitor) = try makeModel()
            let flashDrive = USBDevice(id: 5, name: "USB Flash Drive", speed: .usb3Gen1, connectedAt: at(9, 2))
            monitor.onObservation?(USBObservation(kind: .attached, device: Self.devices[2], observedAt: at(9, 20)))
            monitor.onObservation?(USBObservation(kind: .detached, device: flashDrive, observedAt: at(9, 37)))
            monitor.onDeviceAttached?(Self.devices[0])
            monitor.onObservation?(USBObservation(kind: .attached, device: Self.devices[0], observedAt: at(9, 41)))
            XCTAssertEqual(model.latestConnectedDevice?.id, Self.devices[0].id)
            let png = try render(MenuBarContentView(model: model, bundle: try fixtureBundle()), appearance.name)
            try write(png, "panel-activity-\(appearance.suffix).png")
        }
    }

    func test_settingsScreenshots() throws {
        for appearance in Self.appearances {
            let (model, _) = try makeModel()
            let png = try render(
                SettingsView(model: model, bundle: try fixtureBundle()), appearance.name,
                width: MenubarMetrics.settingsWidth, chrome: .window(title: "usb-boop Settings"))
            try write(png, "settings-\(appearance.suffix).png")
        }
    }

    // MARK: - Helpers

    private func makeModel() throws -> (AppModel, FixtureUSBMonitor) {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ScreenshotTests.\(UUID().uuidString)"))
        let monitor = FixtureUSBMonitor(devices: Self.devices)
        let model = AppModel(
            monitor: monitor, defaults: defaults, loginItem: LoginItemController(service: OffLoginItemService()))
        monitor.start()
        return (model, monitor)
    }

    private func render(
        _ view: some View, _ appearance: NSAppearance.Name, width: CGFloat = MenubarMetrics.panelWidth,
        chrome: PanelSnapshot.Chrome = .panel
    ) throws -> Data {
        let png = try XCTUnwrap(
            PanelSnapshot.png(of: view, width: width, chrome: chrome, appearance: appearance))
        let image = try XCTUnwrap(NSBitmapImageRep(data: png))
        XCTAssertEqual(
            CGFloat(image.pixelsWide), (width + PanelSnapshot.margin * 2) * 2, accuracy: 1)
        return png
    }

    private func write(_ png: Data, _ name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["USB_BOOP_SCREENSHOTS"] else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try png.write(to: url.appendingPathComponent(name))
    }

    /// A stand-in app bundle so the footer and About section show a release
    /// version instead of the test runner's.
    private func fixtureBundle() throws -> Bundle {
        let contents = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotTests-\(UUID().uuidString)/usb-boop.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": "com.alexcatdad.usb-boop.screenshots",
            "CFBundleName": "usb-boop",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "2026.1107.1",
            "CFBundleVersion": "2026.1107.1",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(Bundle(url: contents.deletingLastPathComponent()))
    }
}

/// Today at the given local time, so the screenshots show plausible clock times.
private func at(_ hour: Int, _ minute: Int) -> Date {
    Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
}

@MainActor
private final class OffLoginItemService: LoginItemService {
    var status: LoginItemStatus { .off }
    func register() throws {}
    func unregister() async throws {}
    func openSystemSettings() {}
}

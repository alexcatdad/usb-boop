import AppKit
import MenubarKit
import SwiftUI
import XCTest

@testable import USBBoopKit

@MainActor
final class MenuLayoutTests: XCTestCase {
    func test_largeDeviceListRendersWithinBoundedMenu() throws {
        let devices = (0..<30).map { index in
            USBDevice(
                id: UInt64(index),
                name: index == 0
                    ? "A very long USB device name that should remain accessible when visually truncated"
                    : "USB device \(index)", speed: .usb3Gen1)
        }
        let monitor = FixtureUSBMonitor(devices: devices)
        let model = AppModel(monitor: monitor)
        monitor.start()
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let controller = NSHostingController(
            rootView: MenuBarContentView(model: model)
                .environment(\.colorScheme, .light)
                .background(Color(nsColor: .windowBackgroundColor)))
        let view = controller.view
        view.appearance = NSAppearance(named: .aqua)
        let size = view.fittingSize
        // MenuBarExtra can propose a minimal size instead of the ideal fitting
        // size; the device list must keep its scrolling height even then.
        let minimumSize = controller.sizeThatFits(in: CGSize(width: MenubarMetrics.panelWidth, height: 0))
        let deviceList = MenuBarContentView.deviceListMaxHeight
        XCTAssertGreaterThanOrEqual(minimumSize.height, deviceList + 150)
        XCTAssertLessThanOrEqual(size.height, 700)
        XCTAssertEqual(size.width, MenubarMetrics.panelWidth, accuracy: 1)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        if let destination = ProcessInfo.processInfo.environment["USB_BOOP_RENDER_ARTIFACTS"] {
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: destination).appendingPathComponent("usb-boop-menu.png"))
        }
    }

    func test_latestConnectionAndRecentActivityTilesRender() throws {
        let connected = Date(timeIntervalSince1970: 1_800_000_000)
        let device = USBDevice(
            id: 1, name: "Extreme SSD", manufacturer: "SanDisk", vendorID: 0x0781, productID: 0x55AF,
            speed: .usb3Gen2, connectedAt: connected)
        let hub = USBDevice(id: 2, name: "USB3.1 Hub", speed: .usb3Gen1, isHub: true)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "MenuLayoutTests.\(UUID().uuidString)"))
        let monitor = FixtureUSBMonitor(devices: [device, hub])
        let model = AppModel(monitor: monitor, defaults: defaults)
        model.showHubs = true
        monitor.start()
        monitor.onDeviceAttached?(device)
        monitor.onObservation?(USBObservation(kind: .attached, device: device, observedAt: connected))
        monitor.onObservation?(USBObservation(kind: .detached, device: hub, observedAt: connected))
        XCTAssertEqual(model.latestConnectedDevice?.id, device.id)
        XCTAssertEqual(model.visibleHistory.count, 2)

        let controller = NSHostingController(rootView: MenuBarContentView(model: model))
        let size = controller.view.fittingSize
        XCTAssertEqual(size.width, MenubarMetrics.panelWidth, accuracy: 1)
        XCTAssertLessThanOrEqual(size.height, 700)
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()
        if let destination = ProcessInfo.processInfo.environment["USB_BOOP_RENDER_ARTIFACTS"] {
            let view = controller.view
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: destination).appendingPathComponent("usb-boop-menu-activity.png"))
        }
    }

    func test_deviceRowTextAndCopiedInfo() {
        let connected = Date(timeIntervalSince1970: 1_800_000_000)
        let device = USBDevice(
            id: 1, name: "Extreme SSD", manufacturer: "SanDisk", vendorID: 0x0781, productID: 0x55AF,
            speed: .usb3Gen2, connectedAt: connected)
        XCTAssertEqual(
            device.connectionSummary, "Connected " + connected.formatted(date: .omitted, time: .shortened))
        let hub = USBDevice(id: 2, name: "Hub", speed: .usb3Gen1, isHub: true, firstSeenAt: connected)
        XCTAssertEqual(
            hub.connectionSummary, "Hub · Seen since " + connected.formatted(date: .abbreviated, time: .shortened))
        let info = device.copyableInfo.components(separatedBy: "\n")
        XCTAssertEqual(info.first, "Extreme SSD")
        XCTAssertTrue(info.contains("Link speed: 10 Gbps"))
        XCTAssertTrue(info.contains("Manufacturer: SanDisk"))
        XCTAssertEqual(MenuBarContentView.deviceListMaxHeight, 9 * MenuBarContentView.rowHeight)
        XCTAssertEqual(USBConnectionSpeed.usb3Gen2.tint, .green)
        XCTAssertEqual(USBConnectionSpeed.usb3Gen1.tint, .blue)
        XCTAssertEqual(USBConnectionSpeed.usb2High.tint, .orange)
        XCTAssertEqual(USBConnectionSpeed.usb1Full.tint, .primary)
    }

    func test_settingsRendersOnTheSharedForm() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "MenuLayoutTests.settings.\(UUID().uuidString)"))
        let model = AppModel(monitor: FixtureUSBMonitor(devices: []), defaults: defaults)
        let controller = NSHostingController(rootView: SettingsView(model: model))
        let size = controller.view.fittingSize
        XCTAssertEqual(size.width, MenubarMetrics.settingsWidth, accuracy: 1)
        XCTAssertGreaterThan(size.height, 300)
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()
        if let destination = ProcessInfo.processInfo.environment["USB_BOOP_RENDER_ARTIFACTS"] {
            let view = controller.view
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: destination).appendingPathComponent("usb-boop-settings.png"))
        }
    }
}

import AppKit
import SwiftUI
@testable import USBBoopKit
import XCTest

@MainActor
final class MenuLayoutTests: XCTestCase {
    func test_largeDeviceListRendersWithinBoundedMenu() throws {
        let devices = (0..<30).map { index in
            USBDevice(id: UInt64(index), name: index == 0
                      ? "A very long USB device name that should remain accessible when visually truncated"
                      : "USB device \(index)", speed: .usb3Gen1)
        }
        let monitor = FixtureUSBMonitor(devices: devices)
        let model = AppModel(monitor: monitor)
        monitor.start()
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let controller = NSHostingController(rootView: MenuBarContentView(model: model)
            .environment(\.colorScheme, .light)
            .background(Color(nsColor: .windowBackgroundColor)))
        let view = controller.view
        view.appearance = NSAppearance(named: .aqua)
        let size = view.fittingSize
        // MenuBarExtra can propose a minimal size instead of the ideal fitting size.
        let minimumSize = controller.sizeThatFits(in: CGSize(width: 390, height: 0))
        XCTAssertGreaterThanOrEqual(minimumSize.height, 600)
        XCTAssertLessThanOrEqual(size.height, 740)
        XCTAssertEqual(size.width, 390, accuracy: 1)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        if let destination = ProcessInfo.processInfo.environment["USB_BOOP_RENDER_ARTIFACTS"] {
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: destination).appendingPathComponent("usb-boop-menu.png"))
        }
    }
}

import Foundation

@MainActor
public final class FixtureUSBMonitor: USBMonitoring {
    public var onDevicesChanged: (@MainActor ([USBDevice]) -> Void)?
    public var onDeviceAttached: (@MainActor (USBDevice) -> Void)?

    private let devices: [USBDevice]

    public init(devices: [USBDevice] = PreviewFixtures.connectedDevices) {
        self.devices = devices
    }

    public func start() {
        USBBoopLog.usbMonitor.notice("Starting fixture USB monitor with \(self.devices.count) devices")
        onDevicesChanged?(devices)

        if let newest = devices.first {
            USBBoopLog.usbMonitor.notice(
                "Fixture attached device: \(newest.name, privacy: .public) at \(newest.speed.displayLabel, privacy: .public)"
            )
            onDeviceAttached?(newest)
        }
    }

    public func stop() {}

    public func refresh() {
        USBBoopLog.usbMonitor.debug("Refreshing fixture USB devices")
        onDevicesChanged?(devices)
    }
}

public enum PreviewFixtures {
    public static let connectedDevices: [USBDevice] = [
        USBDevice(
            id: 101,
            name: "iPhone 17 Pro Max",
            manufacturer: "Apple",
            vendorID: 0x05AC,
            productID: 0x12AB,
            locationID: 0x01100000,
            speed: .usb3Gen2,
            connectedAt: .now
        ),
        USBDevice(
            id: 202,
            name: "Samsung T7",
            manufacturer: "Samsung",
            vendorID: 0x04E8,
            productID: 0x61F5,
            locationID: 0x01200000,
            speed: .usb3Gen2,
            connectedAt: .now.addingTimeInterval(-45)
        ),
    ]
}

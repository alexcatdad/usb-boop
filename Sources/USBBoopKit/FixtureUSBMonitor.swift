import Foundation

@MainActor
public final class FixtureUSBMonitor: USBMonitoring {
    public var onDevicesChanged: (@MainActor ([USBDevice]) -> Void)?
    public var onDeviceAttached: (@MainActor (USBDevice) -> Void)?

    public var onDeviceDetached: (@MainActor (USBDevice) -> Void)?
    public var onStatusChanged: (@MainActor (USBMonitoringStatus) -> Void)?
    public var onObservation: (@MainActor (USBObservation) -> Void)?
    public private(set) var status: USBMonitoringStatus = .stopped
    private let devices: [USBDevice]

    public init(devices: [USBDevice] = PreviewFixtures.connectedDevices) { self.devices = devices }

    public func start() {
        guard status == .stopped else { return }
        status = .monitoring
        onStatusChanged?(status)
        onDevicesChanged?(devices)
    }

    public func stop() {
        status = .stopped
        onStatusChanged?(status)
    }

    public func refresh() {
        if status == .stopped { start() } else { onDevicesChanged?(devices) }
    }

    public func reconcileAfterWake() {
        if status != .stopped { refresh() }
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
            firstSeenAt: .now
        ),
        USBDevice(
            id: 202,
            name: "Samsung T7",
            manufacturer: "Samsung",
            vendorID: 0x04E8,
            productID: 0x61F5,
            locationID: 0x01200000,
            speed: .usb3Gen2,
            firstSeenAt: .now.addingTimeInterval(-45)
        ),
    ]
}

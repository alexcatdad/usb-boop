@testable import USBBoopKit
import XCTest

@MainActor
final class MonitoringPresentationTests: XCTestCase {
    func test_staleSnapshotDoesNotClaimDisconnected() {
        let monitor = FixtureUSBMonitor(devices: [])
        let model = AppModel(monitor: monitor)
        monitor.onDeviceAttached?(USBDevice(id: 1, name: "Device", speed: .usb3Gen1))
        monitor.onStatusChanged?(.degraded(.enumerationFailed))
        XCTAssertEqual(model.latestConnectionStatus, "Connection unconfirmed")
        XCTAssertNotNil(model.monitoringMessage)
        monitor.onStatusChanged?(.monitoring)
        XCTAssertEqual(model.latestConnectionStatus, "Disconnected")
        XCTAssertNil(model.monitoringMessage)
    }

    func test_currentSnapshotConfirmsConnection() {
        let monitor = FixtureUSBMonitor(devices: [])
        let model = AppModel(monitor: monitor)
        let device = USBDevice(id: 1, name: "Device", speed: .usb3Gen1)
        monitor.onDeviceAttached?(device)
        monitor.onDevicesChanged?([device])
        monitor.onStatusChanged?(.monitoring)
        XCTAssertEqual(model.latestConnectionStatus, "Connected")
    }
}

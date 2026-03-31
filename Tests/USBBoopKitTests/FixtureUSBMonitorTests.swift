import XCTest
@testable import USBBoopKit

@MainActor
final class FixtureUSBMonitorTests: XCTestCase {

    // MARK: - start

    func test_start_firesOnDevicesChanged() {
        let monitor = FixtureUSBMonitor()
        var receivedDevices: [USBDevice]?

        monitor.onDevicesChanged = { devices in
            receivedDevices = devices
        }

        monitor.start()

        XCTAssertNotNil(receivedDevices, "onDevicesChanged should have been called")
        XCTAssertFalse(receivedDevices!.isEmpty, "Fixture should provide a non-empty device list")
    }

    func test_start_firesOnDeviceAttached() {
        let monitor = FixtureUSBMonitor()
        var attachedDevice: USBDevice?

        monitor.onDeviceAttached = { device in
            attachedDevice = device
        }

        monitor.start()

        XCTAssertNotNil(attachedDevice, "onDeviceAttached should have been called with the first fixture device")
        XCTAssertEqual(attachedDevice?.name, PreviewFixtures.connectedDevices.first?.name)
    }

    // MARK: - stop

    func test_stop_isIdempotent() {
        let monitor = FixtureUSBMonitor()

        // Calling stop() multiple times must not crash.
        monitor.stop()
        monitor.stop()
        monitor.stop()
    }

    // MARK: - refresh

    func test_refresh_firesOnDevicesChanged() {
        let monitor = FixtureUSBMonitor()
        var callCount = 0

        monitor.onDevicesChanged = { _ in
            callCount += 1
        }

        monitor.start()
        XCTAssertEqual(callCount, 1, "start() should fire onDevicesChanged once")

        // Reset tracking and verify refresh fires the callback again.
        callCount = 0
        monitor.refresh()
        XCTAssertEqual(callCount, 1, "refresh() should fire onDevicesChanged again")
    }
}

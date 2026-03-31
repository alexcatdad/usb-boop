@testable import USBBoopKit
import XCTest

@MainActor
final class IOKitUSBMonitorIntegrationTests: XCTestCase {

    func test_startAndStop_lifecycle() async throws {
        let monitor = IOKitUSBMonitor()
        var snapshotCount = 0
        var receivedDevices: [USBDevice] = []

        monitor.onDevicesChanged = { devices in
            snapshotCount += 1
            receivedDevices = devices
        }

        monitor.start()

        // Allow IOKit enumeration to complete
        try await Task.sleep(for: .milliseconds(200))

        // Should have published at least one snapshot (initial prime)
        XCTAssertGreaterThan(snapshotCount, 0, "Expected at least one device snapshot after start")

        monitor.stop()
    }

    func test_start_isIdempotent() async throws {
        let monitor = IOKitUSBMonitor()
        var snapshotCount = 0
        monitor.onDevicesChanged = { _ in snapshotCount += 1 }

        monitor.start()
        monitor.start() // second call should be ignored

        try await Task.sleep(for: .milliseconds(200))
        monitor.stop()

        // Only one start should have registered notifications
        // Snapshot count should be small (1-2 from the single start)
        XCTAssertLessThan(snapshotCount, 5)
    }

    func test_refresh_updatesSnapshot() async throws {
        let monitor = IOKitUSBMonitor()
        var snapshots: [[USBDevice]] = []
        monitor.onDevicesChanged = { devices in snapshots.append(devices) }

        monitor.start()
        try await Task.sleep(for: .milliseconds(200))

        let countBefore = snapshots.count
        monitor.refresh()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertGreaterThan(snapshots.count, countBefore, "refresh() should publish a new snapshot")
        monitor.stop()
    }

    func test_stop_isIdempotent() {
        let monitor = IOKitUSBMonitor()
        monitor.start()
        monitor.stop()
        monitor.stop() // should not crash
    }

    func test_devices_haveValidProperties() async throws {
        let monitor = IOKitUSBMonitor()
        var devices: [USBDevice] = []
        monitor.onDevicesChanged = { devices = $0 }

        monitor.start()
        try await Task.sleep(for: .milliseconds(200))
        monitor.stop()

        // On any Mac, there should be internal USB controllers/hubs
        // We don't assert on count since CI may vary, but if there are devices, verify properties
        for device in devices {
            XCTAssertFalse(device.name.isEmpty, "Device name should not be empty")
            XCTAssertGreaterThan(device.id, 0, "Device ID should be positive")
        }
    }
}

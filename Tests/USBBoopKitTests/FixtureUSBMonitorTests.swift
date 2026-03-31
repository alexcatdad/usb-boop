@testable import USBBoopKit
import XCTest

@MainActor
final class FixtureUSBMonitorTests: XCTestCase {

    func test_start_publishesDevices() {
        let devices = [
            USBDevice(id: 1, name: "Test Device", speed: .usb3Gen1),
        ]
        let monitor = FixtureUSBMonitor(devices: devices)

        var receivedDevices: [USBDevice]?
        monitor.onDevicesChanged = { receivedDevices = $0 }

        monitor.start()

        XCTAssertEqual(receivedDevices?.count, 1)
        XCTAssertEqual(receivedDevices?.first?.name, "Test Device")
    }

    func test_start_firesAttachedForNewest() {
        let devices = [
            USBDevice(id: 1, name: "First", speed: .usb2High),
            USBDevice(id: 2, name: "Second", speed: .usb3Gen1),
        ]
        let monitor = FixtureUSBMonitor(devices: devices)

        var attachedDevice: USBDevice?
        monitor.onDeviceAttached = { attachedDevice = $0 }

        monitor.start()

        XCTAssertEqual(attachedDevice?.name, "First")
    }

    func test_start_emptyDevices_noAttached() {
        let monitor = FixtureUSBMonitor(devices: [])

        var attachedDevice: USBDevice?
        monitor.onDeviceAttached = { attachedDevice = $0 }

        monitor.start()

        XCTAssertNil(attachedDevice)
    }

    func test_refresh_publishesDevicesAgain() {
        let devices = [
            USBDevice(id: 1, name: "D", speed: .usb2High),
        ]
        let monitor = FixtureUSBMonitor(devices: devices)

        var callCount = 0
        monitor.onDevicesChanged = { _ in callCount += 1 }

        monitor.start()
        XCTAssertEqual(callCount, 1)

        monitor.refresh()
        XCTAssertEqual(callCount, 2)
    }

    func test_stop_doesNotCrash() {
        let monitor = FixtureUSBMonitor(devices: [])
        monitor.stop()
        // No crash = success
    }

    func test_defaultDevices_usesPreviewFixtures() {
        let monitor = FixtureUSBMonitor()

        var receivedDevices: [USBDevice]?
        monitor.onDevicesChanged = { receivedDevices = $0 }

        monitor.start()

        XCTAssertEqual(receivedDevices?.count, PreviewFixtures.connectedDevices.count)
    }
}

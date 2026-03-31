import XCTest
@testable import USBBoopKit

final class USBDeviceExtendedTests: XCTestCase {

    // MARK: - notificationBody

    func test_notificationBody_withManufacturer() {
        let device = USBDevice(
            id: 1,
            name: "Logitech Webcam",
            manufacturer: "Logitech",
            speed: .usb2High
        )

        let body = device.notificationBody
        XCTAssertTrue(body.contains("Logitech Webcam"), "Body should contain the device name")
        XCTAssertTrue(body.contains("480 Mbps"), "Body should contain the speed display label")
    }

    func test_notificationBody_withoutManufacturer() {
        let device = USBDevice(
            id: 2,
            name: "Generic Device",
            speed: .usb1Full
        )

        let body = device.notificationBody
        XCTAssertFalse(body.isEmpty, "Notification body should not be empty even without a manufacturer")
        XCTAssertTrue(body.contains("Generic Device"), "Body should still contain the device name")
        XCTAssertTrue(body.contains("12 Mbps"), "Body should contain the speed display label")
    }

    // MARK: - detailSummary

    func test_detailSummary_withAllFields() {
        let device = USBDevice(
            id: 3,
            name: "Samsung T7",
            manufacturer: "Samsung",
            vendorID: 0x04E8,
            productID: 0x61F5,
            locationID: 0x01100000,
            speed: .usb3Gen2
        )

        let summary = device.detailSummary
        XCTAssertTrue(summary.contains("10 Gbps"), "Summary should include display label")
        XCTAssertTrue(summary.contains("USB 3.2 Gen 2"), "Summary should include technical label")
        XCTAssertTrue(summary.contains("Samsung"), "Summary should include manufacturer")
        XCTAssertTrue(summary.contains("Location 0x01100000"), "Summary should include formatted location ID")
    }

    func test_detailSummary_withMinimalFields() {
        let device = USBDevice(
            id: 4,
            name: "Bare Device",
            speed: .unknown
        )

        let summary = device.detailSummary
        XCTAssertFalse(summary.isEmpty, "Summary should still be valid with minimal fields")
        XCTAssertTrue(summary.contains("Speed unavailable"), "Summary should contain the unknown speed label")
    }

    // MARK: - vendorProductSummary

    func test_vendorProductSummary_withBothIDs() {
        let device = USBDevice(
            id: 5,
            name: "Test Device",
            vendorID: 0x04E8,
            productID: 0x61F5,
            speed: .usb3Gen1
        )

        let vps = device.vendorProductSummary
        XCTAssertNotNil(vps)
        XCTAssertEqual(vps, "VID 04E8 / PID 61F5")
    }

    func test_vendorProductSummary_withNilIDs() {
        let device = USBDevice(
            id: 6,
            name: "No IDs",
            speed: .usb2High
        )

        XCTAssertNil(device.vendorProductSummary, "vendorProductSummary should be nil when vendor/product IDs are missing")
    }

    // MARK: - subtitle

    func test_subtitle_usesSpeedTechnicalLabel() {
        let device = USBDevice(
            id: 7,
            name: "Known Speed Device",
            speed: .usb3Gen2
        )

        XCTAssertEqual(device.subtitle, "USB 3.2 Gen 2")
        XCTAssertEqual(device.subtitle, device.speed.technicalLabel)
    }

    func test_subtitle_unknownSpeed_usesDisplayLabel() {
        let device = USBDevice(
            id: 8,
            name: "Unknown Speed Device",
            speed: .unknown
        )

        XCTAssertEqual(device.subtitle, "Speed unavailable")
        XCTAssertEqual(device.subtitle, device.speed.displayLabel)
    }

    // MARK: - Equatable conformance

    func test_equatable_conformance() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let deviceA = USBDevice(
            id: 10,
            name: "Device",
            manufacturer: "Maker",
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "SN001",
            locationID: 0x02000000,
            speed: .usb3Gen1,
            isHub: false,
            connectedAt: date
        )
        let deviceB = USBDevice(
            id: 10,
            name: "Device",
            manufacturer: "Maker",
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "SN001",
            locationID: 0x02000000,
            speed: .usb3Gen1,
            isHub: false,
            connectedAt: date
        )
        let deviceC = USBDevice(
            id: 99,
            name: "Other Device",
            speed: .usb1Low
        )

        XCTAssertEqual(deviceA, deviceB, "Devices with identical properties should be equal")
        XCTAssertNotEqual(deviceA, deviceC, "Devices with different properties should not be equal")
    }

    // MARK: - Identifiable

    func test_identifiable_usesID() {
        let device = USBDevice(
            id: 42,
            name: "ID Test",
            locationID: 0xABCD0000,
            speed: .usb2High
        )

        // Identifiable.id is the `id` stored property (UInt64), not locationID.
        XCTAssertEqual(device.id, 42)
    }
}

import XCTest
@testable import USBBoopKit

final class USBDeviceTests: XCTestCase {
    func testNotificationBodyIncludesFriendlyDeviceNameAndSpeed() {
        let device = USBDevice(
            id: 42,
            name: "Samsung T7",
            manufacturer: "Samsung",
            vendorID: 0x04E8,
            productID: 0x61F5,
            locationID: 0x01100000,
            speed: .usb3Gen2
        )

        XCTAssertEqual(device.notificationBody, "Samsung T7 connected at 10 Gbps")
        XCTAssertTrue(device.detailSummary.contains("10 Gbps"))
        XCTAssertTrue(device.detailSummary.contains("Samsung"))
    }

    func testSubtitleReturnsTechnicalLabelWhenAvailable() {
        let device = USBDevice(id: 1, name: "D", speed: .usb3Gen1)
        XCTAssertEqual(device.subtitle, "USB 3.2 Gen 1")
    }

    func testSubtitleReturnsDisplayLabelForUnknownSpeed() {
        let device = USBDevice(id: 1, name: "D", speed: .unknown)
        XCTAssertEqual(device.subtitle, "Speed unavailable")
    }

    func testVendorProductSummaryWithBothIDs() {
        let device = USBDevice(id: 1, name: "D", vendorID: 0x04E8, productID: 0x61F5, speed: .usb2High)
        XCTAssertEqual(device.vendorProductSummary, "VID 04E8 / PID 61F5")
    }

    func testVendorProductSummaryNilWhenMissingIDs() {
        let device = USBDevice(id: 1, name: "D", speed: .usb2High)
        XCTAssertNil(device.vendorProductSummary)
    }

    func testVendorProductSummaryNilWhenOnlyVendorID() {
        let device = USBDevice(id: 1, name: "D", vendorID: 0x1234, speed: .usb2High)
        XCTAssertNil(device.vendorProductSummary)
    }

    func testDetailSummaryWithoutManufacturerOrLocation() {
        let device = USBDevice(id: 1, name: "D", speed: .usb3Gen2)
        let summary = device.detailSummary
        XCTAssertTrue(summary.contains("10 Gbps"))
        XCTAssertTrue(summary.contains("USB 3.2 Gen 2"))
    }

    func testDetailSummaryWithLocationID() {
        let device = USBDevice(id: 1, name: "D", locationID: 0x01100000, speed: .usb2High)
        XCTAssertTrue(device.detailSummary.contains("Location 0x01100000"))
    }

    func testDetailSummaryUnknownSpeedNoTechnicalLabel() {
        let device = USBDevice(id: 1, name: "D", speed: .unknown)
        let summary = device.detailSummary
        XCTAssertTrue(summary.contains("Speed unavailable"))
        XCTAssertFalse(summary.contains("USB"))
    }
}

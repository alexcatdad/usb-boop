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
}

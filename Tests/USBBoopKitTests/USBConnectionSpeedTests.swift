import XCTest
@testable import USBBoopKit

final class USBConnectionSpeedTests: XCTestCase {
    func testRegistryMappingCoversExpectedUSBSpeeds() {
        XCTAssertEqual(USBConnectionSpeed(registryValue: 2), .usb1Low)
        XCTAssertEqual(USBConnectionSpeed(registryValue: 1), .usb1Full)
        XCTAssertEqual(USBConnectionSpeed(registryValue: 3), .usb2High)
        XCTAssertEqual(USBConnectionSpeed(registryValue: 4), .usb3Gen1)
        XCTAssertEqual(USBConnectionSpeed(registryValue: 5), .usb3Gen2)
        XCTAssertEqual(USBConnectionSpeed(registryValue: 6), .usb3Gen2x2)
        XCTAssertEqual(USBConnectionSpeed(registryValue: 99), .unknown)
    }

    func testDisplayLabelsStayHumanReadable() {
        XCTAssertEqual(USBConnectionSpeed.usb2High.displayLabel, "480 Mbps")
        XCTAssertEqual(USBConnectionSpeed.usb3Gen1.displayLabel, "5 Gbps")
        XCTAssertEqual(USBConnectionSpeed.usb3Gen2.displayLabel, "10 Gbps")
    }
}

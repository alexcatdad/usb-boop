@testable import USBBoopKit
import XCTest

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

    func testAllDisplayLabelsAreNonEmpty() {
        for speed in USBConnectionSpeed.allCases {
            XCTAssertFalse(speed.displayLabel.isEmpty, "\(speed) should have a display label")
        }
    }

    func testAllTechnicalLabelsExceptUnknown() {
        for speed in USBConnectionSpeed.allCases {
            if speed == .unknown {
                XCTAssertNil(speed.technicalLabel, "unknown should have nil technical label")
            } else {
                XCTAssertNotNil(speed.technicalLabel, "\(speed) should have a technical label")
            }
        }
    }

func testRegistryValueNilMapsToUnknown() {
        XCTAssertEqual(USBConnectionSpeed(registryValue: nil), .unknown)
    }

    func testRegistryValueOtherMapsToOther() {
        XCTAssertEqual(USBConnectionSpeed(registryValue: 7), .other)
    }

    func testRegistryValueZeroMapsToUnknown() {
        XCTAssertEqual(USBConnectionSpeed(registryValue: 0), .unknown)
    }
}

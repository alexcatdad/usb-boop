import XCTest
@testable import USBBoopKit

final class USBConnectionSpeedAllCasesTests: XCTestCase {

    func test_allCases_haveTechnicalLabel_exceptUnknown() {
        for speed in USBConnectionSpeed.allCases {
            if speed == .unknown {
                XCTAssertNil(speed.technicalLabel, ".unknown should have nil technicalLabel")
            } else {
                XCTAssertNotNil(
                    speed.technicalLabel,
                    "\(speed) should have a non-nil technicalLabel"
                )
            }
        }
    }

    func test_allCases_haveNonEmptyDisplayLabel() {
        for speed in USBConnectionSpeed.allCases {
            XCTAssertFalse(
                speed.displayLabel.isEmpty,
                "\(speed) should have a non-empty displayLabel"
            )
        }
    }

    func test_registryValue_roundTrip() {
        // Map of registry values to expected (case, displayLabel) pairs.
        let expectations: [(registryValue: Int, expectedCase: USBConnectionSpeed, expectedLabel: String)] = [
            (2, .usb1Low, "1.5 Mbps"),
            (1, .usb1Full, "12 Mbps"),
            (3, .usb2High, "480 Mbps"),
            (4, .usb3Gen1, "5 Gbps"),
            (5, .usb3Gen2, "10 Gbps"),
            (6, .usb3Gen2x2, "20 Gbps"),
        ]

        for (registryValue, expectedCase, expectedLabel) in expectations {
            let speed = USBConnectionSpeed(registryValue: registryValue)
            XCTAssertEqual(speed, expectedCase, "Registry value \(registryValue) should map to \(expectedCase)")
            XCTAssertEqual(speed.displayLabel, expectedLabel, "Display label mismatch for registry value \(registryValue)")
        }
    }

    func test_unknownRegistryValue_returnsUnknown() {
        // Out-of-range registry values should fall back to .unknown.
        let speed = USBConnectionSpeed(registryValue: 99)
        XCTAssertEqual(speed, .unknown)
    }

    func test_displayLabel_includesSpeed() {
        // .usb3Gen2 operates at 10 Gbps; the display label must contain "10".
        let label = USBConnectionSpeed.usb3Gen2.displayLabel
        XCTAssertTrue(label.contains("10"), "Expected '10' in displayLabel, got: \(label)")
    }
}

@testable import USBBoopKit
import XCTest

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
        // Map of registry values to expected case and displayLabel.
        let registryValues =  [2, 1, 3, 4, 5, 6]
        let expectedCases: [USBConnectionSpeed] = [
            .usb1Low, .usb1Full, .usb2High, .usb3Gen1, .usb3Gen2, .usb3Gen2x2,
        ]
        let expectedLabels = [
            "1.5 Mbps", "12 Mbps", "480 Mbps", "5 Gbps", "10 Gbps", "20 Gbps",
        ]

        for index in registryValues.indices {
            let speed = USBConnectionSpeed(registryValue: registryValues[index])
            XCTAssertEqual(
                speed, expectedCases[index],
                "Registry value \(registryValues[index]) should map to \(expectedCases[index])"
            )
            XCTAssertEqual(
                speed.displayLabel, expectedLabels[index],
                "Display label mismatch for registry value \(registryValues[index])"
            )
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

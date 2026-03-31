import XCTest
@testable import USBBoopKit

final class USBRegistryDeviceReaderTests: XCTestCase {
    private let reader = USBRegistryDeviceReader()

    // MARK: - sanitize

    func test_sanitize_nil_returnsNil() {
        XCTAssertNil(reader.sanitize(nil))
    }

    func test_sanitize_normalString_unchanged() {
        XCTAssertEqual(reader.sanitize("Samsung T7"), "Samsung T7")
    }

    func test_sanitize_stripsControlCharacters() {
        XCTAssertEqual(reader.sanitize("Bad\u{0000}Device"), "BadDevice")
    }

    func test_sanitize_stripsNullBytes() {
        XCTAssertEqual(reader.sanitize("A\u{0000}B"), "AB")
    }

    func test_sanitize_stripsRTLOverride() {
        // U+202E is right-to-left override (a format code point)
        let input = "Device\u{202E}Name"
        let result = reader.sanitize(input)
        XCTAssertEqual(result, "DeviceName")
    }

    func test_sanitize_truncatesTo128() {
        let long = String(repeating: "A", count: 200)
        let result = reader.sanitize(long)
        XCTAssertEqual(result?.count, 128)
    }

    func test_sanitize_allControlChars_returnsNil() {
        XCTAssertNil(reader.sanitize("\u{0000}\u{0001}\u{0002}"))
    }

    func test_sanitize_emptyString_returnsNil() {
        XCTAssertNil(reader.sanitize(""))
    }

    // MARK: - resolvedName

    func test_resolvedName_withProductName() {
        let name = reader.resolvedName(productName: "iPhone", vendorName: "Apple", vendorID: 0x05AC, productID: 0x1234)
        XCTAssertEqual(name, "iPhone")
    }

    func test_resolvedName_noProduct_usesVendor() {
        let name = reader.resolvedName(productName: nil, vendorName: "Samsung", vendorID: 0x04E8, productID: 0x6001)
        XCTAssertEqual(name, "Samsung USB Device")
    }

    func test_resolvedName_emptyProduct_usesVendor() {
        let name = reader.resolvedName(productName: "", vendorName: "Samsung", vendorID: nil, productID: nil)
        XCTAssertEqual(name, "Samsung USB Device")
    }

    func test_resolvedName_noNames_usesIDs() {
        let name = reader.resolvedName(productName: nil, vendorName: nil, vendorID: 0x1234, productID: 0x5678)
        XCTAssertEqual(name, "USB Device 1234:5678")
    }

    func test_resolvedName_nothing_fallback() {
        let name = reader.resolvedName(productName: nil, vendorName: nil, vendorID: nil, productID: nil)
        XCTAssertEqual(name, "USB Device")
    }

    func test_resolvedName_emptyVendor_usesIDs() {
        let name = reader.resolvedName(productName: nil, vendorName: "", vendorID: 0xABCD, productID: 0x0001)
        XCTAssertEqual(name, "USB Device ABCD:0001")
    }
}

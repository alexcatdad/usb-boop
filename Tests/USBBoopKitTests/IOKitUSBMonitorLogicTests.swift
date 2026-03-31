import XCTest
@testable import USBBoopKit

final class USBDeviceMergerTests: XCTestCase {

    // MARK: - merge

    func test_merge_noExisting_returnsNewDevice() {
        let device = makeDevice(id: 1, name: "New", speed: .usb3Gen1)
        let result = USBDeviceMerger.merge(device, withKnownDevice: nil)
        XCTAssertEqual(result, device)
    }

    func test_merge_fillsNilManufacturer() {
        let device = makeDevice(id: 1, name: "D", manufacturer: nil)
        let existing = makeDevice(id: 1, name: "D", manufacturer: "ACME")
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.manufacturer, "ACME")
    }

    func test_merge_newManufacturerWins() {
        let device = makeDevice(id: 1, name: "D", manufacturer: "New")
        let existing = makeDevice(id: 1, name: "D", manufacturer: "Old")
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.manufacturer, "New")
    }

    func test_merge_fillsNilVendorID() {
        let device = makeDevice(id: 1, name: "D", vendorID: nil)
        let existing = makeDevice(id: 1, name: "D", vendorID: 0x1234)
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.vendorID, 0x1234)
    }

    func test_merge_fillsNilProductID() {
        let device = makeDevice(id: 1, name: "D", productID: nil)
        let existing = makeDevice(id: 1, name: "D", productID: 0x5678)
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.productID, 0x5678)
    }

    func test_merge_fillsNilSerialNumber() {
        let device = makeDevice(id: 1, name: "D", serialNumber: nil)
        let existing = makeDevice(id: 1, name: "D", serialNumber: "SN123")
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.serialNumber, "SN123")
    }

    func test_merge_fillsNilLocationID() {
        let device = makeDevice(id: 1, name: "D", locationID: nil)
        let existing = makeDevice(id: 1, name: "D", locationID: 42)
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.locationID, 42)
    }

    func test_merge_unknownSpeedFallsBackToExisting() {
        let device = makeDevice(id: 1, name: "D", speed: .unknown)
        let existing = makeDevice(id: 1, name: "D", speed: .usb3Gen2)
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.speed, .usb3Gen2)
    }

    func test_merge_knownSpeedOverridesExisting() {
        let device = makeDevice(id: 1, name: "D", speed: .usb3Gen1)
        let existing = makeDevice(id: 1, name: "D", speed: .usb2High)
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.speed, .usb3Gen1)
    }

    func test_merge_preservesExistingConnectedAt() {
        let old = Date.now.addingTimeInterval(-60)
        let device = makeDevice(id: 1, name: "D")
        let existing = makeDevice(id: 1, name: "D", connectedAt: old)
        let result = USBDeviceMerger.merge(device, withKnownDevice: existing)
        XCTAssertEqual(result.connectedAt, old)
    }

    // MARK: - sorted

    func test_sorted_newerDevicesFirst() {
        let old = makeDevice(id: 1, name: "Old", connectedAt: .now.addingTimeInterval(-60))
        let new = makeDevice(id: 2, name: "New", connectedAt: .now)
        let result = USBDeviceMerger.sorted([old, new])
        XCTAssertEqual(result.map(\.id), [2, 1])
    }

    func test_sorted_sameTime_alphabetical() {
        let time = Date.now
        let b = makeDevice(id: 1, name: "Bravo", connectedAt: time)
        let a = makeDevice(id: 2, name: "Alpha", connectedAt: time)
        let result = USBDeviceMerger.sorted([b, a])
        XCTAssertEqual(result.map(\.name), ["Alpha", "Bravo"])
    }

    func test_sorted_empty() {
        let result = USBDeviceMerger.sorted([USBDevice]())
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - helpers

    private func makeDevice(
        id: UInt64 = 1, name: String = "Device",
        manufacturer: String? = nil, vendorID: Int? = nil,
        productID: Int? = nil, serialNumber: String? = nil,
        locationID: UInt32? = nil, speed: USBConnectionSpeed = .usb3Gen1,
        isHub: Bool = false, connectedAt: Date = .now
    ) -> USBDevice {
        USBDevice(id: id, name: name, manufacturer: manufacturer, vendorID: vendorID,
                  productID: productID, serialNumber: serialNumber, locationID: locationID,
                  speed: speed, isHub: isHub, connectedAt: connectedAt)
    }
}

@testable import USBBoopKit
import XCTest

@MainActor
final class ConnectionAlertBatcherTests: XCTestCase {
    func test_fixedWindowGroupsAndDeduplicatesWithoutSoundPolicy() async {
        var release: CheckedContinuation<Void, Never>?
        var waits = 0
        var batches: [[USBDevice]] = []
        let batcher = ConnectionAlertBatcher(wait: {
            waits += 1
            await withCheckedContinuation { release = $0 }
        }, deliver: { batches.append($0) })
        let first = USBDevice(id: 1, name: "First", speed: .usb3Gen1)
        batcher.enqueue(first)
        await Task.yield()
        batcher.enqueue(first)
        batcher.enqueue(USBDevice(id: 2, name: "Second", speed: .usb2High))
        batcher.enqueue(USBDevice(id: 3, name: "Hub", speed: .usb3Gen1, isHub: true))
        XCTAssertEqual(waits, 1)
        release?.resume()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches.first?.map(\.id), [1, 2])
    }

    func test_cancelAndDetachDiscardPendingAlerts() async {
        var release: CheckedContinuation<Void, Never>?
        var batches: [[USBDevice]] = []
        let batcher = ConnectionAlertBatcher(wait: {
            await withCheckedContinuation { release = $0 }
        }, deliver: { batches.append($0) })
        batcher.enqueue(USBDevice(id: 1, name: "First", speed: .usb3Gen1))
        await Task.yield()
        batcher.remove(1)
        release?.resume()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(batches.isEmpty)
        batcher.enqueue(USBDevice(id: 2, name: "Second", speed: .usb2High))
        await Task.yield()
        batcher.cancel()
        release?.resume()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(batches.isEmpty)
    }
}

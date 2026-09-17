@testable import USBBoopKit
import XCTest

@MainActor
final class USBMonitorRecoveryTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_000)

    func testStartStopStartAndPartialRegistrationFailureAreRecoverable() {
        let registry = TestUSBRegistry()
        registry.startIssue = .registrationFailed
        let monitor = IOKitUSBMonitor(registry: registry)
        monitor.start()
        XCTAssertEqual(monitor.status, .degraded(.registrationFailed))
        XCTAssertGreaterThan(registry.stopCount, 0)
        registry.startIssue = nil
        monitor.refresh()
        XCTAssertEqual(monitor.status, .monitoring)
        XCTAssertEqual(registry.startCount, 2)
        monitor.stop()
        monitor.start()
        XCTAssertEqual(registry.startCount, 3)
        XCTAssertEqual(monitor.status, .monitoring)
        monitor.stop()
    }

    func testStartupHasObservationTimeButNoInventedAttachOrHistory() {
        let registry = TestUSBRegistry(devices: [device(1)])
        let monitor = IOKitUSBMonitor(registry: registry, now: { self.time })
        var received: [USBDevice] = []
        var attaches = 0
        var observations: [USBObservation] = []
        monitor.onDevicesChanged = { received = $0 }
        monitor.onDeviceAttached = { _ in attaches += 1 }
        monitor.onObservation = { observations.append($0) }
        monitor.start()
        XCTAssertEqual(received.first?.firstSeenAt, time)
        XCTAssertNil(received.first?.connectedAt)
        XCTAssertEqual(attaches, 0)
        XCTAssertTrue(observations.isEmpty)
    }

    func testEnumerationFailureRetainsSnapshotAndDenialDoesNotRetryOnWake() {
        let registry = TestUSBRegistry(devices: [device(1)])
        let monitor = IOKitUSBMonitor(registry: registry)
        var received: [USBDevice] = []
        monitor.onDevicesChanged = { received = $0 }
        monitor.start()
        registry.result = .failure(.accessRestricted)
        monitor.refresh()
        XCTAssertEqual(received.map(\.id), [1])
        XCTAssertEqual(monitor.status, .degraded(.accessRestricted))
        let count = registry.snapshotCount
        monitor.reconcileAfterWake()
        XCTAssertEqual(registry.snapshotCount, count)
        XCTAssertEqual(registry.startCount, 1)
        registry.result = .success(USBRegistrySnapshot(devices: []))
        monitor.refresh()
        XCTAssertEqual(monitor.status, .monitoring)
        XCTAssertEqual(registry.startCount, 2)
        XCTAssertTrue(received.isEmpty)
    }

    func testDuplicateCallbacksOnlyProduceOneAttachAndOneDetach() {
        let registry = TestUSBRegistry()
        let monitor = IOKitUSBMonitor(registry: registry, now: { self.time })
        var attaches: [USBDevice] = []
        var detaches: [USBDevice] = []
        var observations: [USBObservation] = []
        monitor.onDeviceAttached = { attaches.append($0) }
        monitor.onDeviceDetached = { detaches.append($0) }
        monitor.onObservation = { observations.append($0) }
        monitor.start()
        let snapshot = USBRegistrySnapshot(devices: [device(1)])
        registry.onAttached?(snapshot)
        registry.onAttached?(snapshot)
        registry.onDetached?([1, 1])
        XCTAssertEqual(attaches.count, 1)
        XCTAssertEqual(detaches.count, 1)
        XCTAssertEqual(attaches.first?.connectedAt, time)
        XCTAssertEqual(observations.map(\.kind), [.attached, .detached])
        XCTAssertNil(observations.first?.device.serialNumber)
    }

    func testWakeReconcilesDifferencesWithoutAlertsOrExactConnectionTimes() {
        let registry = TestUSBRegistry(devices: [device(1)])
        let monitor = IOKitUSBMonitor(registry: registry)
        var observations: [USBObservation] = []
        var attaches = 0
        monitor.onObservation = { observations.append($0) }
        monitor.onDeviceAttached = { _ in attaches += 1 }
        monitor.start()
        registry.result = .success(USBRegistrySnapshot(devices: [device(2)]))
        monitor.reconcileAfterWake()
        XCTAssertEqual(registry.startCount, 2)
        XCTAssertEqual(Set(observations.map(\.kind)), [.firstSeen, .noLongerDetected])
        XCTAssertTrue(observations.allSatisfy { $0.device.connectedAt == nil })
        XCTAssertEqual(attaches, 0)
    }

    func testPartialSnapshotRetainsUnconfirmedDevicesAndPublishesIdentifiableOnes() {
        let registry = TestUSBRegistry(devices: [device(1)])
        let monitor = IOKitUSBMonitor(registry: registry)
        var received: [USBDevice] = []
        var observations: [USBObservation] = []
        monitor.onDevicesChanged = { received = $0 }
        monitor.onObservation = { observations.append($0) }
        monitor.start()
        registry.result = .success(USBRegistrySnapshot(devices: [device(2)], issue: .incompleteResults))
        monitor.refresh()
        XCTAssertEqual(Set(received.map(\.id)), [1, 2])
        XCTAssertEqual(monitor.status, .degraded(.incompleteResults))
        XCTAssertFalse(monitor.status.isSnapshotReliable)
        XCTAssertEqual(observations.map(\.kind), [.firstSeen])
    }

    func testFailedWakeRegistrationStaysDegradedEvenWithSuccessfulSnapshot() {
        let registry = TestUSBRegistry(devices: [device(1)])
        let monitor = IOKitUSBMonitor(registry: registry)
        monitor.start()
        registry.startIssue = .registrationFailed
        monitor.reconcileAfterWake()
        XCTAssertEqual(monitor.status, .degraded(.registrationFailed))
        XCTAssertTrue(monitor.status.canRetry)
        XCTAssertFalse(monitor.status.isSnapshotReliable)
    }

    func testAttachMetadataDenialKeepsDeviceAndStopsBackgroundAccess() {
        let registry = TestUSBRegistry()
        let monitor = IOKitUSBMonitor(registry: registry)
        var received: [USBDevice] = []
        monitor.onDevicesChanged = { received = $0 }
        monitor.start()
        registry.onAttached?(USBRegistrySnapshot(devices: [device(1)], issue: .accessRestricted))
        XCTAssertEqual(received.map(\.id), [1])
        XCTAssertEqual(monitor.status, .degraded(.accessRestricted))
        XCTAssertGreaterThan(registry.stopCount, 0)
        monitor.reconcileAfterWake()
        XCTAssertEqual(registry.startCount, 1)
    }

    func testStoppedMonitorIgnoresWakeAndReleasesCallbacks() {
        let registry = TestUSBRegistry()
        let monitor = IOKitUSBMonitor(registry: registry)
        monitor.start()
        monitor.stop()
        monitor.reconcileAfterWake()
        XCTAssertEqual(registry.startCount, 1)
        XCTAssertNil(registry.onAttached)
        XCTAssertNil(registry.onDetached)
        XCTAssertNil(registry.onIssue)
        XCTAssertEqual(monitor.status, .stopped)
    }

    func testDeniedRegistrationDoesNotEnumerateUntilExplicitRetry() {
        let registry = TestUSBRegistry()
        registry.startIssue = .accessRestricted
        let monitor = IOKitUSBMonitor(registry: registry)
        monitor.start()
        monitor.start()
        monitor.reconcileAfterWake()
        XCTAssertEqual(registry.snapshotCount, 0)
        XCTAssertEqual(registry.startCount, 1)
        XCTAssertEqual(monitor.status, .unavailable(.accessRestricted))
    }

    func testMissingPropertiesRetainDeviceAndFutureSpeedRemainsUnknown() {
        let reader = USBRegistryDeviceReader()
        let missing = reader.makeDevice(id: 42, properties: [:])
        XCTAssertEqual(missing.id, 42)
        XCTAssertEqual(missing.name, "USB Device")
        XCTAssertEqual(missing.speed, .unknown)
        XCTAssertNil(missing.connectedAt)
        let future = reader.makeDevice(id: 42, properties: ["USBSpeed": NSNumber(value: 99)])
        XCTAssertEqual(future.speed, .unknown)
        XCTAssertEqual(future.rawRegistrySpeed, 99)
    }

    private func device(_ identifier: UInt64) -> USBDevice {
        USBDevice(id: identifier, name: "Device", serialNumber: "sensitive", speed: .usb3Gen1)
    }
}

@MainActor
private final class TestUSBRegistry: USBRegistryAccess {
    var onAttached: ((USBRegistrySnapshot) -> Void)?
    var onDetached: (([UInt64]) -> Void)?
    var onIssue: ((USBMonitoringIssue) -> Void)?
    var startIssue: USBMonitoringIssue?
    var startCount = 0
    var stopCount = 0
    var snapshotCount = 0
    var result: Result<USBRegistrySnapshot, USBMonitoringIssue>

    init(devices: [USBDevice] = []) { result = .success(USBRegistrySnapshot(devices: devices)) }
    func start() -> USBMonitoringIssue? { startCount += 1; return startIssue }
    func stop() { stopCount += 1 }
    func snapshot() -> Result<USBRegistrySnapshot, USBMonitoringIssue> {
        snapshotCount += 1
        return result
    }
}

@testable import USBBoopKit
import UserNotifications
import XCTest

@MainActor
private final class SuspendedNotificationCenter: NotificationCenterProtocol {
    var status: UNAuthorizationStatus = .authorized
    var shouldSuspend = false
    var entered: (() -> Void)?
    var continuation: CheckedContinuation<Void, Never>?
    var added = 0

    func authorizationStatus() async -> UNAuthorizationStatus {
        let captured = status
        if shouldSuspend {
            shouldSuspend = false
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                entered?()
            }
        }
        return captured
    }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func add(_ request: UNNotificationRequest) async throws { added += 1 }
}

@MainActor
private final class NotificationCenterSelection {
    var center: SuspendedNotificationCenter
    init(_ center: SuspendedNotificationCenter) { self.center = center }
}

@MainActor
final class NotificationLifecycleTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "com.alexcatdad.usb-boop.race-tests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return UserDefaults(suiteName: name) ?? .standard
    }

    func test_oldCoordinatorCannotOverwriteRestartedAuthorization() async {
        let old = SuspendedNotificationCenter()
        old.status = .denied
        let new = SuspendedNotificationCenter()
        let selection = NotificationCenterSelection(old)
        let model = AppModel(monitor: FixtureUSBMonitor(devices: []), makeNotifier: {
            UserNotificationCoordinator(center: selection.center)
        }, defaults: defaults())
        model.start()
        await model.refreshAuthorization()
        let entered = expectation(description: "old settings check suspended")
        old.shouldSuspend = true
        old.entered = { entered.fulfill() }
        let refresh = Task { await model.refreshAuthorization() }
        await fulfillment(of: [entered], timeout: 2)
        model.stop()
        selection.center = new
        model.start()
        await model.refreshAuthorization()
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        old.continuation?.resume()
        await refresh.value
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        model.stop()
    }

    func test_detachDisableAndStopCancelDeliveryAwaitingAuthorization() async {
        for action in ["detach", "disable", "stop"] {
            let center = SuspendedNotificationCenter()
            let monitor = FixtureUSBMonitor(devices: [])
            let model = AppModel(monitor: monitor, makeNotifier: { UserNotificationCoordinator(center: center) },
                                 defaults: defaults(), alertWait: { })
            model.start()
            await model.refreshAuthorization()
            await model.setNotificationsEnabled(true)
            let entered = expectation(description: "delivery settings check suspended: \(action)")
            center.shouldSuspend = true
            center.entered = { entered.fulfill() }
            let device = USBDevice(id: 1, name: "Device", speed: .usb3Gen1)
            monitor.onDeviceAttached?(device)
            await fulfillment(of: [entered], timeout: 2)
            switch action {
            case "detach": monitor.onDeviceDetached?(device)
            case "disable": await model.setNotificationsEnabled(false)
            default: model.stop()
            }
            center.continuation?.resume()
            await model.refreshAuthorization()
            for _ in 0..<10 { await Task.yield() }
            XCTAssertEqual(center.added, 0, action)
            model.stop()
        }
    }
}

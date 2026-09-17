@testable import USBBoopKit
import UserNotifications
import XCTest

@MainActor
private final class AuthorizationTestCenter: NotificationCenterProtocol {
    var status: UNAuthorizationStatus = .notDetermined
    var requestError: Error?
    var suspendRequest = false
    var requestStarted: (() -> Void)?
    var continuation: CheckedContinuation<Void, Never>?
    var requestCount = 0

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestCount += 1
        if suspendRequest {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                requestStarted?()
            }
        }
        if let requestError { throw requestError }
        status = .authorized
        return true
    }

    func add(_ request: UNNotificationRequest) async throws { }

    func finishRequest() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class AuthorizationCenterSelection {
    var center: AuthorizationTestCenter
    init(_ center: AuthorizationTestCenter) { self.center = center }
}

@MainActor
final class NotificationAuthorizationTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "com.alexcatdad.usb-boop.authorization-tests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return UserDefaults(suiteName: name) ?? .standard
    }

    func test_requestErrorIsVisibleAndExplicitRetryCanRecover() async {
        let center = AuthorizationTestCenter()
        let detail = "Notification service could not register this app."
        center.requestError = NSError(domain: "AuthorizationTest", code: 19,
                                      userInfo: [NSLocalizedDescriptionKey: detail])
        let model = AppModel(monitor: FixtureUSBMonitor(devices: []), makeNotifier: {
            UserNotificationCoordinator(center: center)
        }, defaults: defaults())
        model.start()
        await model.refreshAuthorization()
        await model.setNotificationsEnabled(true)

        XCTAssertEqual(model.notificationAuthorization, .failed(detail))
        XCTAssertTrue(model.notificationAuthorizationSummary.contains(detail))
        XCTAssertFalse(model.isRequestingNotificationAuthorization)
        XCTAssertTrue(model.canRequestNotifications)
        XCTAssertTrue(model.notificationsEnabled)

        center.requestError = nil
        await model.setNotificationsEnabled(true)
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        XCTAssertFalse(model.isRequestingNotificationAuthorization)
        XCTAssertEqual(center.requestCount, 2)
        model.stop()
    }

    func test_concurrentEnableActionsShareOnePendingRequest() async {
        let center = AuthorizationTestCenter()
        center.suspendRequest = true
        let detail = "Notification permission request failed."
        center.requestError = NSError(domain: "AuthorizationTest", code: 19,
                                      userInfo: [NSLocalizedDescriptionKey: detail])
        let started = expectation(description: "permission request started")
        center.requestStarted = { started.fulfill() }
        let model = AppModel(monitor: FixtureUSBMonitor(devices: []), makeNotifier: {
            UserNotificationCoordinator(center: center)
        }, defaults: defaults())
        model.start()
        await model.refreshAuthorization()
        let first = Task { await model.setNotificationsEnabled(true) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(model.isRequestingNotificationAuthorization)
        XCTAssertEqual(model.notificationAuthorizationSummary, "Waiting for notification permission…")

        let second = Task { await model.setNotificationsEnabled(true) }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(center.requestCount, 1)
        center.suspendRequest = false
        center.finishRequest()
        await first.value
        await second.value
        XCTAssertEqual(center.requestCount, 1)
        XCTAssertEqual(model.notificationAuthorization, .failed(detail))
        XCTAssertFalse(model.isRequestingNotificationAuthorization)
        model.stop()
    }

    func test_refreshPreservesRequestErrorUntilAuthorizationChanges() async {
        let center = AuthorizationTestCenter()
        let detail = "Notifications are not allowed for this application."
        center.requestError = NSError(domain: UNErrorDomain, code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: detail])
        let model = AppModel(monitor: FixtureUSBMonitor(devices: []), makeNotifier: {
            UserNotificationCoordinator(center: center)
        }, defaults: defaults())
        model.start()
        await model.refreshAuthorization()
        await model.setNotificationsEnabled(true)

        await model.refreshAuthorization()
        XCTAssertEqual(model.notificationAuthorization, .failed(detail))
        XCTAssertTrue(model.notificationAuthorizationSummary.contains(detail))
        XCTAssertEqual(center.requestCount, 1, "A refresh must never request permission")

        center.status = .authorized
        await model.refreshAuthorization()
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        XCTAssertFalse(model.notificationAuthorizationSummary.contains(detail))
        XCTAssertEqual(center.requestCount, 1)
        model.stop()
    }

    func test_stoppedRequestCannotClearRestartedPendingState() async {
        let old = AuthorizationTestCenter()
        old.suspendRequest = true
        let oldStarted = expectation(description: "old request started")
        old.requestStarted = { oldStarted.fulfill() }
        let selection = AuthorizationCenterSelection(old)
        let model = AppModel(monitor: FixtureUSBMonitor(devices: []), makeNotifier: {
            UserNotificationCoordinator(center: selection.center)
        }, defaults: defaults())
        model.start()
        await model.refreshAuthorization()
        let oldRequest = Task { await model.setNotificationsEnabled(true) }
        await fulfillment(of: [oldStarted], timeout: 2)
        model.stop()
        XCTAssertFalse(model.isRequestingNotificationAuthorization)

        let current = AuthorizationTestCenter()
        current.suspendRequest = true
        let currentStarted = expectation(description: "current request started")
        current.requestStarted = { currentStarted.fulfill() }
        selection.center = current
        model.start()
        await model.refreshAuthorization()
        XCTAssertFalse(model.isRequestingNotificationAuthorization)
        let currentRequest = Task { await model.setNotificationsEnabled(true) }
        await fulfillment(of: [currentStarted], timeout: 2)
        old.finishRequest()
        await oldRequest.value
        XCTAssertTrue(model.isRequestingNotificationAuthorization)
        XCTAssertEqual(model.notificationAuthorization, .notDetermined)

        current.finishRequest()
        await currentRequest.value
        XCTAssertFalse(model.isRequestingNotificationAuthorization)
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        model.stop()
    }
}

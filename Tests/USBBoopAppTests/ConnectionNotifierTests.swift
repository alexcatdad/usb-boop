import MenubarKit
import UserNotifications
import XCTest

@testable import USBBoopKit

/// Preferences a test can flip between deliveries, as the Settings toggles would.
private final class TestPreferences: @unchecked Sendable {
    // Only mutated from the main-actor test body between awaits; never read concurrently.
    var value = NotificationPreferences(enabled: true, soundEnabled: false)
}

@MainActor
final class ConnectionNotifierTests: XCTestCase {
    private let preferences = TestPreferences()

    private func notifier(_ center: MockNotificationCenter) -> ConnectionNotifier {
        let preferences = preferences
        return ConnectionNotifier(center: center, preferences: { preferences.value })
    }

    func test_existingAuthorizationDoesNotPrompt() async {
        for status in [UNAuthorizationStatus.authorized, .provisional] {
            let center = MockNotificationCenter()
            center.mockStatus = status
            let state = await notifier(center).requestAuthorization()
            XCTAssertEqual(state, .authorized)
            XCTAssertEqual(center.requestCount, 0)
        }
    }

    func test_denialDoesNotPromptAgain() async {
        let center = MockNotificationCenter()
        center.mockStatus = .denied
        let state = await notifier(center).requestAuthorization()
        XCTAssertEqual(state, .denied)
        XCTAssertEqual(center.requestCount, 0)
    }

    func test_explicitEnableCanBeGrantedOrDenied() async {
        for granted in [true, false] {
            let center = MockNotificationCenter()
            center.grantOnRequest = granted
            let state = await notifier(center).requestAuthorization()
            XCTAssertEqual(state, granted ? .authorized : .denied)
            XCTAssertEqual(center.requestCount, 1)
        }
    }

    func test_requestErrorIsDistinctFromDenialAndRefreshCanRecover() async {
        let center = MockNotificationCenter()
        center.requestError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No service"])
        let notifier = notifier(center)
        let state = await notifier.requestAuthorization()
        XCTAssertEqual(state, .failed("No service"))
        let refreshed = await notifier.authorization()
        XCTAssertEqual(refreshed, .notDetermined)
        center.requestError = nil
        let retried = await notifier.requestAuthorization()
        XCTAssertEqual(retried, .authorized)
    }

    func test_refreshNeverPromptsAndTracksExternalChanges() async {
        let center = MockNotificationCenter()
        let notifier = notifier(center)
        for (status, expected) in [
            (UNAuthorizationStatus.notDetermined, NotificationAuthorization.notDetermined),
            (.authorized, .authorized), (.denied, .denied),
        ] {
            center.mockStatus = status
            let state = await notifier.authorization()
            XCTAssertEqual(state, expected)
        }
        XCTAssertEqual(center.requestCount, 0)
    }

    func test_singleDeviceNotificationIsSilentAndContainsLinkSpeed() async throws {
        let center = MockNotificationCenter()
        center.mockStatus = .authorized
        let outcome = await notifier(center).deliver([device()])
        XCTAssertEqual(outcome, .delivered)
        let posted = try XCTUnwrap(center.addedRequests.first)
        XCTAssertTrue(posted.notification.identifier.hasPrefix("usb-boop."))
        XCTAssertEqual(posted.notification.title, device().name)
        XCTAssertEqual(posted.notification.body, device().notificationBody)
        XCTAssertTrue(posted.notification.body.contains("10 Gbps"))
        XCTAssertNil(posted.notification.subtitle)
        XCTAssertTrue(posted.notification.userInfo.isEmpty)
        XCTAssertFalse(posted.playSound)
        XCTAssertEqual(posted.notification.threadIdentifier, "usb-boop.connections")
    }

    func test_soundFollowsPreferenceAndIdentifiersAreUnique() async {
        let center = MockNotificationCenter()
        center.mockStatus = .authorized
        let notifier = notifier(center)
        preferences.value.soundEnabled = true
        await notifier.deliver([device()])
        preferences.value.soundEnabled = false
        await notifier.deliver([device()])
        XCTAssertEqual(center.addedRequests.map(\.playSound), [true, false])
        XCTAssertNotEqual(
            center.addedRequests[0].notification.identifier,
            center.addedRequests[1].notification.identifier)
    }

    func test_toggleOffIsReadAtDelivery() async {
        let center = MockNotificationCenter()
        center.mockStatus = .authorized
        preferences.value.enabled = false
        let outcome = await notifier(center).deliver([device()])
        XCTAssertEqual(outcome, .disabled)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func test_groupedNotificationIncludesCountAndMenuHintAndExcludesHubs() throws {
        let notification = try XCTUnwrap(
            ConnectionNotifier.notification(
                for: [device(), device(id: 43), device(id: 44, isHub: true)], identifier: "fixed"))
        XCTAssertEqual(
            notification,
            MenubarNotification(
                title: "2 USB devices connected", body: "Open usb-boop for link speeds.",
                threadIdentifier: "usb-boop.connections", identifier: "fixed"))
    }

    func test_hubsAndEmptyBatchesDoNotNotifyOrQueryAuthorization() async {
        let center = MockNotificationCenter()
        center.mockStatus = .authorized
        let notifier = notifier(center)
        let empty = await notifier.deliver([])
        let hub = await notifier.deliver([device(isHub: true)])
        XCTAssertNil(empty)
        XCTAssertNil(hub)
        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(center.statusReadCount, 0)
    }

    func test_unknownSpeedDoesNotInventSubtitle() throws {
        let notification = try XCTUnwrap(ConnectionNotifier.notification(for: [device(speed: .unknown)]))
        XCTAssertNil(notification.subtitle)
        XCTAssertTrue(notification.body.lowercased().contains("unavailable"))
    }

    func test_deliveryRespectsRevokedAuthorizationAndNeverPrompts() async {
        let center = MockNotificationCenter()
        let notifier = notifier(center)
        for status in [UNAuthorizationStatus.denied, .notDetermined] {
            center.mockStatus = status
            let outcome = await notifier.deliver([device()])
            XCTAssertEqual(outcome, .notAuthorized)
        }
        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(center.requestCount, 0)
    }

    func test_cancelledDeliveryNeverPosts() async {
        let center = MockNotificationCenter()
        center.mockStatus = .authorized
        let notifier = notifier(center)
        let delivery = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await notifier.deliver([self.device()])
        }
        let outcome = await delivery.value
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func test_submissionErrorReturnsFailureAndNextSubmissionCanSucceed() async {
        let center = MockNotificationCenter()
        center.mockStatus = .authorized
        center.shouldThrowOnAdd = true
        let notifier = notifier(center)
        let failed = await notifier.deliver([device()])
        guard case .failed = failed else { return XCTFail("Expected failure") }
        center.shouldThrowOnAdd = false
        let recovered = await notifier.deliver([device()])
        XCTAssertEqual(recovered, .delivered)
        XCTAssertEqual(center.addedRequests.count, 1)
    }

    private func device(id: UInt64 = 42, speed: USBConnectionSpeed = .usb3Gen2, isHub: Bool = false) -> USBDevice {
        USBDevice(id: id, name: "Test Device", speed: speed, isHub: isHub)
    }
}

@testable import USBBoopKit
import UserNotifications
import XCTest

@MainActor
final class MockNotificationCenter: NotificationCenterProtocol {
    var mockStatus: UNAuthorizationStatus = .notDetermined
    var grantOnRequest = true
    var shouldThrowOnRequest = false
    var shouldThrowOnAdd = false
    var suspendRequest = false
    var requestContinuation: CheckedContinuation<Void, Never>?
    var onRequestStarted: (() -> Void)?
    var addedRequests: [UNNotificationRequest] = []
    var requestedOptions: [UNAuthorizationOptions] = []
    var statusReadCount = 0

    func authorizationStatus() async -> UNAuthorizationStatus {
        statusReadCount += 1
        return mockStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions.append(options)
        if suspendRequest {
            await withCheckedContinuation { continuation in
                requestContinuation = continuation
                onRequestStarted?()
            }
        }
        if shouldThrowOnRequest { throw NSError(domain: "test", code: 1) }
        mockStatus = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func add(_ request: UNNotificationRequest) async throws {
        if shouldThrowOnAdd { throw NSError(domain: "test", code: 2) }
        addedRequests.append(request)
    }
}

@MainActor
final class UserNotificationCoordinatorTests: XCTestCase {
    func test_existingAuthorizationDoesNotPrompt() async {
        for status in [UNAuthorizationStatus.authorized, .provisional] {
            let mock = MockNotificationCenter()
            mock.mockStatus = status
            let coord = UserNotificationCoordinator(center: mock)
            let state = await coord.requestAuthorizationIfNeeded()
            XCTAssertEqual(state, .authorized)
            XCTAssertTrue(mock.requestedOptions.isEmpty)
        }
    }

    func test_denialDoesNotPromptAgain() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .denied
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .denied)
        XCTAssertTrue(mock.requestedOptions.isEmpty)
    }

    func test_explicitEnableRequestsOnlyAlertAndSound() async {
        let mock = MockNotificationCenter()
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(mock.requestedOptions, [[.alert, .sound]])
        XCTAssertEqual(coord.authorizationState, .authorized)
    }

    func test_explicitEnableCanBeDenied() async {
        let mock = MockNotificationCenter()
        mock.grantOnRequest = false
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .denied)
    }

    func test_requestErrorIsDistinctFromDenialAndRefreshCanRecover() async {
        let mock = MockNotificationCenter()
        mock.shouldThrowOnRequest = true
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        guard case .failed = state else { return XCTFail("Expected an authorization request error") }
        let recovered = await coord.refreshAuthorizationState()
        XCTAssertEqual(recovered, .notDetermined)
        XCTAssertEqual(mock.requestedOptions.count, 1)
    }

    func test_refreshNeverPromptsAndTracksExternalChanges() async {
        let mock = MockNotificationCenter()
        let coord = UserNotificationCoordinator(center: mock)
        for (status, expected) in [
            (UNAuthorizationStatus.notDetermined, UserNotificationCoordinator.AuthorizationState.notDetermined),
            (.authorized, .authorized), (.denied, .denied)
        ] {
            mock.mockStatus = status
            let state = await coord.refreshAuthorizationState()
            XCTAssertEqual(state, expected)
            XCTAssertEqual(coord.authorizationState, expected)
        }
        XCTAssertTrue(mock.requestedOptions.isEmpty)
    }

    func test_refreshWaitsForPendingPermissionRequest() async {
        let mock = MockNotificationCenter()
        mock.suspendRequest = true
        let coord = UserNotificationCoordinator(center: mock)
        let requestTask = Task { await coord.requestAuthorizationIfNeeded() }
        await withCheckedContinuation { continuation in
            if mock.requestContinuation != nil {
                continuation.resume()
            } else {
                mock.onRequestStarted = { continuation.resume() }
            }
        }
        let refreshTask = Task { await coord.refreshAuthorizationState() }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(mock.statusReadCount, 1, "Refresh must not read pre-prompt settings")
        mock.requestContinuation?.resume()
        mock.requestContinuation = nil
        let requested = await requestTask.value
        let refreshed = await refreshTask.value
        XCTAssertEqual(requested, .authorized)
        XCTAssertEqual(refreshed, .authorized)
        XCTAssertEqual(coord.authorizationState, .authorized)
        XCTAssertEqual(mock.requestedOptions.count, 1)
    }

    func test_singleDeviceNotificationIsSilentAndContainsLinkSpeed() async throws {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        let coord = UserNotificationCoordinator(center: mock)
        let sent = await coord.sendConnectionNotification(for: [device()])
        XCTAssertTrue(sent)
        let request = try XCTUnwrap(mock.addedRequests.first)
        XCTAssertTrue(request.identifier.hasPrefix("usb-boop."))
        XCTAssertEqual(request.content.title, device().name)
        XCTAssertEqual(request.content.body, device().notificationBody)
        XCTAssertTrue(request.content.body.contains("10 Gbps"))
        XCTAssertEqual(request.content.subtitle, "")
        XCTAssertNil(request.content.sound)
        XCTAssertEqual(request.content.threadIdentifier, "usb-boop.connections")
    }

    func test_soundRequiresExplicitPreferenceAndIdentifiersAreUnique() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        let coord = UserNotificationCoordinator(center: mock)
        _ = await coord.sendConnectionNotification(for: [device()], soundEnabled: true)
        _ = await coord.sendConnectionNotification(for: [device()])
        XCTAssertNotNil(mock.addedRequests[0].content.sound)
        XCTAssertNil(mock.addedRequests[1].content.sound)
        XCTAssertNotEqual(mock.addedRequests[0].identifier, mock.addedRequests[1].identifier)
    }

    func test_groupedNotificationIncludesCountAndMenuHintAndExcludesHubs() async throws {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        let coord = UserNotificationCoordinator(center: mock)
        let sent = await coord.sendConnectionNotification(for: [device(), device(id: 43), device(id: 44, isHub: true)])
        XCTAssertTrue(sent)
        let request = try XCTUnwrap(mock.addedRequests.first)
        XCTAssertEqual(request.content.title, "2 USB devices connected")
        XCTAssertEqual(request.content.body, "Open usb-boop for link speeds.")
        XCTAssertEqual(request.content.subtitle, "")
    }

    func test_hubsAndEmptyBatchesDoNotNotifyOrQueryAuthorization() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        let coord = UserNotificationCoordinator(center: mock)
        let emptySent = await coord.sendConnectionNotification(for: [])
        let hubSent = await coord.sendConnectionNotification(for: [device(isHub: true)])
        XCTAssertFalse(emptySent)
        XCTAssertFalse(hubSent)
        XCTAssertTrue(mock.addedRequests.isEmpty)
        XCTAssertEqual(mock.statusReadCount, 0)
    }

    func test_unknownSpeedDoesNotInventSubtitle() async throws {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        let coord = UserNotificationCoordinator(center: mock)
        _ = await coord.sendConnectionNotification(for: [device(speed: .unknown)])
        let request = try XCTUnwrap(mock.addedRequests.first)
        XCTAssertEqual(request.content.subtitle, "")
        XCTAssertTrue(request.content.body.lowercased().contains("unavailable"))
    }

    func test_submissionRespectsRevokedAuthorizationAndNeverPrompts() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        let coord = UserNotificationCoordinator(center: mock)
        _ = await coord.refreshAuthorizationState()
        for status in [UNAuthorizationStatus.denied, .notDetermined] {
            mock.mockStatus = status
            let sent = await coord.sendConnectionNotification(for: [device()])
            XCTAssertFalse(sent)
        }
        XCTAssertTrue(mock.addedRequests.isEmpty)
        XCTAssertTrue(mock.requestedOptions.isEmpty)
    }

    func test_submissionErrorReturnsFailureAndNextSubmissionCanSucceed() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        mock.shouldThrowOnAdd = true
        let coord = UserNotificationCoordinator(center: mock)
        let failed = await coord.sendConnectionNotification(for: [device()])
        XCTAssertFalse(failed)
        mock.shouldThrowOnAdd = false
        let recovered = await coord.sendConnectionNotification(for: [device()])
        XCTAssertTrue(recovered)
        XCTAssertEqual(mock.addedRequests.count, 1)
    }

    private func device(id: UInt64 = 42, speed: USBConnectionSpeed = .usb3Gen2, isHub: Bool = false) -> USBDevice {
        USBDevice(id: id, name: "Test Device", speed: speed, isHub: isHub)
    }
}

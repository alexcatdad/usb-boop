import XCTest
import UserNotifications
@testable import USBBoopKit

/// Mock notification center for testing.
@MainActor
final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var mockStatus: UNAuthorizationStatus = .notDetermined
    var grantOnRequest = true
    var shouldThrowOnRequest = false
    var addedRequests: [UNNotificationRequest] = []
    var shouldThrowOnAdd = false

    func authorizationStatus() async -> UNAuthorizationStatus {
        mockStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if shouldThrowOnRequest { throw NSError(domain: "test", code: 1) }
        return grantOnRequest
    }

    func add(_ request: UNNotificationRequest) async throws {
        if shouldThrowOnAdd { throw NSError(domain: "test", code: 2) }
        addedRequests.append(request)
    }
}

@MainActor
final class UserNotificationCoordinatorTests: XCTestCase {

    // MARK: - requestAuthorizationIfNeeded

    func test_requestAuth_whenAuthorized_returnsAuthorized() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .authorized)
    }

    func test_requestAuth_whenProvisional_returnsAuthorized() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .provisional
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .authorized)
    }

    func test_requestAuth_whenDenied_returnsDenied() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .denied
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .denied)
    }

    func test_requestAuth_whenNotDetermined_andGranted_returnsAuthorized() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .notDetermined
        mock.grantOnRequest = true
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .authorized)
    }

    func test_requestAuth_whenNotDetermined_andDenied_returnsDenied() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .notDetermined
        mock.grantOnRequest = false
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .denied)
    }

    func test_requestAuth_whenNotDetermined_andThrows_returnsDenied() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .notDetermined
        mock.shouldThrowOnRequest = true
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.requestAuthorizationIfNeeded()
        XCTAssertEqual(state, .denied)
    }

    // MARK: - refreshAuthorizationState

    func test_refresh_whenAuthorized_returnsAuthorized() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .authorized
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.refreshAuthorizationState()
        XCTAssertEqual(state, .authorized)
    }

    func test_refresh_whenDenied_returnsDenied() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .denied
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.refreshAuthorizationState()
        XCTAssertEqual(state, .denied)
    }

    func test_refresh_whenNotDetermined_returnsNotDetermined() async {
        let mock = MockNotificationCenter()
        mock.mockStatus = .notDetermined
        let coord = UserNotificationCoordinator(center: mock)
        let state = await coord.refreshAuthorizationState()
        XCTAssertEqual(state, .notDetermined)
    }

    // MARK: - sendConnectionNotification

    func test_sendNotification_createsCorrectRequest() async throws {
        let mock = MockNotificationCenter()
        let device = USBDevice(
            id: 42, name: "Test Device", manufacturer: "ACME",
            vendorID: 0x1234, productID: 0x5678, serialNumber: nil,
            locationID: 1, speed: .usb3Gen2, isHub: false
        )
        let coord = UserNotificationCoordinator(center: mock)
        coord.sendConnectionNotification(for: device)

        // Give the Task time to complete
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mock.addedRequests.count, 1)
        let request = try XCTUnwrap(mock.addedRequests.first)
        XCTAssertTrue(request.identifier.hasPrefix("usb-boop.42."))
        XCTAssertEqual(request.content.title, "USB Connected")
        XCTAssertEqual(request.content.body, device.notificationBody)
        XCTAssertEqual(request.content.subtitle, device.speed.technicalLabel)
        XCTAssertEqual(request.content.threadIdentifier, "usb-boop.connections")
    }

    func test_sendNotification_unknownSpeed_noSubtitle() async throws {
        let mock = MockNotificationCenter()
        let device = USBDevice(
            id: 99, name: "Mystery", manufacturer: nil,
            vendorID: nil, productID: nil, serialNumber: nil,
            locationID: nil, speed: .unknown, isHub: false
        )
        let coord = UserNotificationCoordinator(center: mock)
        coord.sendConnectionNotification(for: device)

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mock.addedRequests.count, 1)
        let request = try XCTUnwrap(mock.addedRequests.first)
        XCTAssertEqual(request.content.subtitle, "")
    }

    func test_sendNotification_errorDoesNotCrash() async throws {
        let mock = MockNotificationCenter()
        mock.shouldThrowOnAdd = true
        let device = USBDevice(
            id: 1, name: "D", manufacturer: nil,
            vendorID: nil, productID: nil, serialNumber: nil,
            locationID: nil, speed: .usb2High, isHub: false
        )
        let coord = UserNotificationCoordinator(center: mock)
        coord.sendConnectionNotification(for: device)

        try await Task.sleep(for: .milliseconds(50))
        // No crash = success
    }
}

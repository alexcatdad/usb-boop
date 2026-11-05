import MenubarKit
import UserNotifications

/// One `add` call on a fake notification center.
struct PostedNotification: Equatable {
    let notification: MenubarNotification
    let playSound: Bool
}

/// A scriptable `NotificationCenterClient`; production uses MenubarKit's `SystemNotificationCenter`.
@MainActor
final class MockNotificationCenter: NotificationCenterClient {
    var mockStatus: UNAuthorizationStatus = .notDetermined
    var grantOnRequest = true
    var requestError: Error?
    var shouldThrowOnAdd = false
    var addedRequests: [PostedNotification] = []
    var requestCount = 0
    var statusReadCount = 0

    func authorizationStatus() async -> UNAuthorizationStatus {
        statusReadCount += 1
        return mockStatus
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        if let requestError { throw requestError }
        mockStatus = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func add(_ notification: MenubarNotification, playSound: Bool) async throws {
        if shouldThrowOnAdd { throw NSError(domain: "test", code: 2) }
        addedRequests.append(PostedNotification(notification: notification, playSound: playSound))
    }
}

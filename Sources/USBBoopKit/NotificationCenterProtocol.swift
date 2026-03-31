import UserNotifications

/// Protocol wrapping UNUserNotificationCenter for testability.
@MainActor
public protocol NotificationCenterProtocol {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    public func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

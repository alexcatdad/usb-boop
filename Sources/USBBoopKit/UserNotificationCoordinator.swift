import Foundation
import OSLog
@preconcurrency import UserNotifications

@MainActor
public final class UserNotificationCoordinator {
    public enum AuthorizationState: Sendable {
        case notDetermined
        case denied
        case authorized
    }

    private let centerProvider: @MainActor () -> UNUserNotificationCenter

    public init(centerProvider: @escaping @MainActor () -> UNUserNotificationCenter = { .current() }) {
        self.centerProvider = centerProvider
    }

    public func requestAuthorizationIfNeeded() async -> AuthorizationState {
        let center = centerProvider()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .ephemeral, .provisional:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                return granted ? .authorized : .denied
            } catch {
                return .denied
            }
        @unknown default:
            return .denied
        }
    }

    public func refreshAuthorizationState() async -> AuthorizationState {
        let center = centerProvider()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .ephemeral, .provisional:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    public func sendConnectionNotification(for device: USBDevice) {
        let center = centerProvider()
        let content = UNMutableNotificationContent()
        content.title = "USB Connected"
        content.body = device.notificationBody
        content.sound = .default
        content.threadIdentifier = "usb-boop.connections"

        if let technicalLabel = device.speed.technicalLabel {
            content.subtitle = technicalLabel
        }

        let request = UNNotificationRequest(
            identifier: "usb-boop.\(device.id).\(Int(device.connectedAt.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        Task {
            do {
                try await center.add(request)
            } catch {
                USBBoopLog.appModel.error("Failed to deliver notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

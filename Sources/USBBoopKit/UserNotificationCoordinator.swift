import Foundation
@preconcurrency import UserNotifications

public final class UserNotificationCoordinator: @unchecked Sendable {
    public enum AuthorizationState: Sendable {
        case notDetermined
        case denied
        case authorized
    }

    private let centerProvider: () -> UNUserNotificationCenter

    public init(centerProvider: @escaping () -> UNUserNotificationCenter = { .current() }) {
        self.centerProvider = centerProvider
    }

    public func requestAuthorizationIfNeeded(completion: @escaping @Sendable (AuthorizationState) -> Void) {
        let center = centerProvider()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .ephemeral, .provisional:
                completion(.authorized)
            case .denied:
                completion(.denied)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    completion(granted ? .authorized : .denied)
                }
            @unknown default:
                completion(.denied)
            }
        }
    }

    public func refreshAuthorizationState(completion: @escaping @Sendable (AuthorizationState) -> Void) {
        let center = centerProvider()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .ephemeral, .provisional:
                completion(.authorized)
            case .denied:
                completion(.denied)
            case .notDetermined:
                completion(.notDetermined)
            @unknown default:
                completion(.denied)
            }
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

        center.add(request)
    }
}

import Foundation
import MenubarKit
import USBBoopKit

/// What the notification controls show about macOS permission.
enum NotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    /// The permission request itself failed; macOS has not recorded an answer, so the user can retry.
    case failed(String)

    init(_ permission: NotificationPermission) {
        switch permission {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        }
    }
}

/// usb-boop's connection banners, posted through MenubarKit's `MenubarNotifier`.
///
/// `MenubarNotifier` owns opt-in, sound, the permission re-check at delivery,
/// cancellation and one-request-at-a-time. This type adds the usb-boop mapping
/// (one banner per batch, hubs skipped, thread `usb-boop.connections`) and keeps
/// a failed permission request's reason for the Settings view.
final class ConnectionNotifier: Sendable {
    static let threadIdentifier = "usb-boop.connections"

    private let notifier: MenubarNotifier

    init(
        center: any NotificationCenterClient = SystemNotificationCenter(),
        preferences: @escaping @Sendable () -> NotificationPreferences
    ) {
        notifier = MenubarNotifier(center: center, preferences: preferences)
    }

    /// The current permission. Never prompts.
    func authorization() async -> NotificationAuthorization {
        NotificationAuthorization(await notifier.permission())
    }

    /// Call only from the user's toggle or Enable button. Prompts if macOS has not asked yet.
    func requestAuthorization() async -> NotificationAuthorization {
        do {
            return NotificationAuthorization(try await notifier.requestPermission())
        } catch PermissionRequestError.alreadyInProgress {
            return await authorization()
        } catch {
            let failure = error as NSError
            USBBoopLog.appModel.error(
                "Notification authorization failed: \(failure.domain, privacy: .public) code \(failure.code)"
            )
            return .failed(error.localizedDescription)
        }
    }

    /// Posts one banner for `devices`, unless they are all hubs, the toggle is off,
    /// permission was revoked, or the calling task was cancelled meanwhile.
    @discardableResult
    func deliver(_ devices: [USBDevice]) async -> DeliveryOutcome? {
        guard let notification = Self.notification(for: devices) else { return nil }
        let outcome = await notifier.deliver(notification)
        if case .failed(let reason) = outcome, outcome != .cancelled {
            USBBoopLog.appModel.error("Failed to deliver notification: \(reason, privacy: .public)")
        }
        return outcome
    }

    /// The banner for devices connected together, or `nil` when every device is a hub.
    static func notification(for devices: [USBDevice], identifier: String = "usb-boop.\(UUID().uuidString)")
        -> MenubarNotification?
    {
        let eligible = devices.filter { !$0.isHub }
        guard let first = eligible.first else { return nil }
        let single = eligible.count == 1
        return MenubarNotification(
            title: single ? first.name : "\(eligible.count) USB devices connected",
            body: single ? first.notificationBody : "Open usb-boop for link speeds.",
            threadIdentifier: threadIdentifier,
            identifier: identifier
        )
    }
}

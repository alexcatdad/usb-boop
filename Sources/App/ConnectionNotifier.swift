import Foundation
import MenubarKit
import os
import USBBoopKit
import UserNotifications

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
/// `MenubarNotifier` owns opt-in, sound and the permission re-check at delivery.
/// This type adds the usb-boop mapping (one banner per batch, hubs skipped,
/// thread `usb-boop.connections`) and two behaviours MenubarKit does not have:
/// a cancelled delivery never posts, and a failed permission request keeps its reason.
final class ConnectionNotifier: Sendable {
    static let threadIdentifier = "usb-boop.connections"

    private let center: GuardedNotificationCenter
    private let notifier: MenubarNotifier

    init(
        center: any NotificationCenterClient = SystemNotificationCenter(),
        preferences: @escaping @Sendable () -> NotificationPreferences
    ) {
        let guarded = GuardedNotificationCenter(base: center)
        self.center = guarded
        notifier = MenubarNotifier(center: guarded, preferences: preferences)
    }

    /// The current permission. Never prompts.
    func authorization() async -> NotificationAuthorization {
        NotificationAuthorization(await notifier.permission())
    }

    /// Call only from the user's toggle or Enable button. Prompts if macOS has not asked yet.
    func requestAuthorization() async -> NotificationAuthorization {
        center.clearRequestFailure()
        let permission = await notifier.userEnabledNotifications()
        if permission == .denied, let failure = center.clearRequestFailure() {
            return .failed(failure)
        }
        return NotificationAuthorization(permission)
    }

    /// Posts one banner for `devices`, unless they are all hubs, the toggle is off,
    /// permission was revoked, or the calling task was cancelled meanwhile.
    @discardableResult
    func deliver(_ devices: [USBDevice]) async -> DeliveryOutcome? {
        guard let notification = Self.notification(for: devices) else { return nil }
        let outcome = await notifier.deliver(notification)
        if case .failed(let reason) = outcome, !Task.isCancelled {
            USBBoopLog.appModel.error("Failed to deliver notification: \(reason, privacy: .public)")
        }
        return outcome
    }

    /// The banner for devices connected together, or `nil` when every device is a hub.
    static func notification(for devices: [USBDevice], identifier: String = "usb-boop.\(UUID().uuidString)")
        -> MenubarNotification? {
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

/// Wraps the notification center to refuse posting from a cancelled task (a device
/// disconnected, or notifications were turned off, while permission was being checked)
/// and to remember why a permission request threw.
private final class GuardedNotificationCenter: NotificationCenterClient {
    private let base: any NotificationCenterClient
    private let requestFailure = OSAllocatedUnfairLock<String?>(initialState: nil)

    init(base: any NotificationCenterClient) {
        self.base = base
    }

    @discardableResult
    func clearRequestFailure() -> String? {
        requestFailure.withLock { failure in
            defer { failure = nil }
            return failure
        }
    }

    func requestAuthorization() async throws -> Bool {
        do {
            return try await base.requestAuthorization()
        } catch {
            let failure = error as NSError
            USBBoopLog.appModel.error(
                "Notification authorization failed: \(failure.domain, privacy: .public) code \(failure.code)"
            )
            requestFailure.withLock { $0 = error.localizedDescription }
            throw error
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await base.authorizationStatus()
    }

    func add(_ notification: MenubarNotification, playSound: Bool) async throws {
        try Task.checkCancellation()
        try await base.add(notification, playSound: playSound)
    }
}

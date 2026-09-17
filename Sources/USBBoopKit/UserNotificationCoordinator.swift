import Foundation
import OSLog
@preconcurrency import UserNotifications

/// All authorization operations are serialized on the main actor. Calling refresh never prompts.
@MainActor
public final class UserNotificationCoordinator {
    public enum AuthorizationState: Sendable, Equatable {
        case notDetermined
        case denied
        case authorized
        case failed(String)
    }

    public private(set) var authorizationState: AuthorizationState = .notDetermined
    private let center: any NotificationCenterProtocol
    private var authorizationTask: Task<AuthorizationState, Never>?

    public init(center: any NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Call only in response to the user's explicit Enable notifications action.
    public func requestAuthorizationIfNeeded() async -> AuthorizationState {
        await updateAuthorization(requestIfNeeded: true)
    }

    public func refreshAuthorizationState() async -> AuthorizationState {
        await updateAuthorization(requestIfNeeded: false)
    }

    /// The caller must also gate connections by its preference and authorization at observation time.
    /// Checks system authorization again at delivery to respect permission changes without replaying events.
    public func sendConnectionNotification(for devices: [USBDevice], soundEnabled: Bool = false) async -> Bool {
        let eligibleDevices = devices.filter { !$0.isHub }
        guard !eligibleDevices.isEmpty else { return false }
        guard await refreshAuthorizationState() == .authorized,
              authorizationState == .authorized, !Task.isCancelled else { return false }

        let content = UNMutableNotificationContent()
        if eligibleDevices.count == 1, let device = eligibleDevices.first {
            content.title = "USB Connected"
            content.body = device.notificationBody
            content.subtitle = device.speed.technicalLabel ?? ""
        } else {
            content.title = "USB Devices Connected"
            content.body = "\(eligibleDevices.count) devices connected. Open usb-boop from the menu bar for link speeds."
        }
        content.sound = soundEnabled ? .default : nil
        content.threadIdentifier = "usb-boop.connections"

        let request = UNNotificationRequest(
            identifier: "usb-boop.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
            return true
        } catch {
            USBBoopLog.appModel.error("Failed to deliver notification: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func updateAuthorization(requestIfNeeded: Bool) async -> AuthorizationState {
        let precedingTask = authorizationTask
        let task = Task { @MainActor in
            _ = await precedingTask?.value
            let state = await self.readAuthorization(requestIfNeeded: requestIfNeeded)
            self.authorizationState = state
            return state
        }
        authorizationTask = task
        return await task.value
    }

    private func readAuthorization(requestIfNeeded: Bool) async -> AuthorizationState {
        switch await center.authorizationStatus() {
        case .authorized, .ephemeral, .provisional:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            guard requestIfNeeded else { return .notDetermined }
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                return granted ? .authorized : .denied
            } catch {
                return .failed(error.localizedDescription)
            }
        @unknown default:
            return .failed("Notification authorization is unavailable.")
        }
    }
}

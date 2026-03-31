import Foundation
import Observation
import OSLog
import USBBoopKit

@MainActor
@Observable
final class AppModel {
    var currentDevices: [USBDevice] = []
    var latestConnectedDevice: USBDevice?
    var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
        }
    }
    var keepLatestResultPinned: Bool {
        didSet {
            defaults.set(keepLatestResultPinned, forKey: Self.keepLatestResultPinnedKey)
        }
    }
    var notificationAuthorizationSummary = "Checking notification permission…"
    var showHubs: Bool {
        didSet {
            defaults.set(showHubs, forKey: Self.showHubsKey)
        }
    }

    var visibleDevices: [USBDevice] {
        showHubs ? currentDevices : currentDevices.filter { !$0.isHub }
    }

    private let monitor: any USBMonitoring
    private let makeNotifier: @MainActor @Sendable () -> UserNotificationCoordinator
    private var notifier: UserNotificationCoordinator?
    private let defaults: UserDefaults
    private var hasStarted = false

    static let notificationsEnabledKey = "notificationsEnabled"
    static let keepLatestResultPinnedKey = "keepLatestResultPinned"
    static let showHubsKey = "showHubs"

    init(
        monitor: any USBMonitoring = USBMonitorFactory.makeMonitor(),
        makeNotifier: @escaping @MainActor @Sendable () -> UserNotificationCoordinator = { UserNotificationCoordinator() },
        defaults: UserDefaults = .standard
    ) {
        self.monitor = monitor
        self.makeNotifier = makeNotifier
        self.defaults = defaults
        self.notificationsEnabled = defaults.object(forKey: Self.notificationsEnabledKey) as? Bool ?? true
        self.keepLatestResultPinned = defaults.object(forKey: Self.keepLatestResultPinnedKey) as? Bool ?? true
        self.showHubs = defaults.object(forKey: Self.showHubsKey) as? Bool ?? false

        bindMonitor()
    }

    var latestResultTitle: String {
        latestConnectedDevice?.notificationBody ?? "Waiting for a USB device"
    }

    var latestResultDetail: String {
        if let latestConnectedDevice {
            return latestConnectedDevice.detailSummary
        }

        return "Plug in a device and usb-boop will surface the negotiated link speed here."
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        USBBoopLog.appModel.notice(
            "App model starting; notificationsEnabled=\(self.notificationsEnabled) keepLatestResultPinned=\(self.keepLatestResultPinned)"
        )
        notifier = makeNotifier()
        monitor.start()
        refreshNotificationAuthorization()
        requestNotificationsIfNeeded()
    }

    func refreshDevices() {
        monitor.refresh()
    }

    private func bindMonitor() {
        monitor.onDevicesChanged = { [weak self] devices in
            guard let self else { return }
            USBBoopLog.appModel.notice("Received device snapshot with \(devices.count) devices")
            self.currentDevices = devices
        }

        monitor.onDeviceAttached = { [weak self] device in
            guard let self else { return }

            self.latestConnectedDevice = device
            USBBoopLog.appModel.notice(
                "Device attached in app model: \(device.name, privacy: .public) at \(device.speed.displayLabel, privacy: .public)"
            )

            if self.notificationsEnabled, let notifier = self.notifier {
                USBBoopLog.appModel.notice("Sending user notification for \(device.name, privacy: .public)")
                notifier.sendConnectionNotification(for: device)
            } else {
                USBBoopLog.appModel.notice("Notifications disabled; not sending alert for \(device.name, privacy: .public)")
            }
        }
    }

    private func requestNotificationsIfNeeded() {
        guard let notifier else {
            return
        }

        Task {
            let state = await notifier.requestAuthorizationIfNeeded()
            self.notificationAuthorizationSummary = Self.description(for: state)
            USBBoopLog.appModel.notice("Notification authorization state after request: \(Self.description(for: state), privacy: .public)")
        }
    }

    private func refreshNotificationAuthorization() {
        guard let notifier else {
            return
        }

        Task {
            let state = await notifier.refreshAuthorizationState()
            self.notificationAuthorizationSummary = Self.description(for: state)
            USBBoopLog.appModel.debug("Refreshed notification authorization: \(Self.description(for: state), privacy: .public)")
        }
    }

    private static func description(for state: UserNotificationCoordinator.AuthorizationState) -> String {
        switch state {
        case .authorized:
            return "Notifications are enabled."
        case .denied:
            return "Notifications are disabled for usb-boop in macOS Notification Center."
        case .notDetermined:
            return "usb-boop will ask for notification permission the first time it launches."
        }
    }
}

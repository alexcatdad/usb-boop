import Foundation
import MenubarKit
import Observation
import USBBoopKit

@MainActor
@Observable
final class AppModel {
    private(set) var monitoringStatus: USBMonitoringStatus = .stopped
    private(set) var currentDevices: [USBDevice] = []
    private(set) var latestConnectedDevice: USBDevice?
    private(set) var history: [USBObservation] = []
    private(set) var notificationAuthorization: NotificationAuthorization = .notDetermined
    private(set) var isRequestingNotificationAuthorization = false
    private(set) var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
            if !notificationsEnabled { alertBatcher.cancel() }
        }
    }
    var notificationSoundEnabled: Bool {
        didSet { defaults.set(notificationSoundEnabled, forKey: Self.notificationSoundEnabledKey) }
    }
    var keepLatestResultPinned: Bool {
        didSet { defaults.set(keepLatestResultPinned, forKey: Self.keepLatestResultPinnedKey) }
    }
    var showHubs: Bool {
        didSet { defaults.set(showHubs, forKey: Self.showHubsKey) }
    }

    let loginItem: LoginItemController
    private let monitor: any USBMonitoring
    private let makeNotificationCenter: @MainActor @Sendable () -> any NotificationCenterClient
    private var notifier: ConnectionNotifier?
    private let defaults: UserDefaults
    private let alertWait: ConnectionAlertBatcher.Wait
    private var hasStarted = false
    private var alertedConnections: Set<UInt64> = []
    @ObservationIgnored private lazy var alertBatcher = ConnectionAlertBatcher(wait: alertWait) { [weak self] devices in
        await self?.deliverConnectionAlert(for: devices)
    }

    nonisolated static let notificationsEnabledKey = "notificationsEnabled"
    nonisolated static let notificationSoundEnabledKey = "notificationSoundEnabled"
    static let keepLatestResultPinnedKey = "keepLatestResultPinned"
    static let showHubsKey = "showHubs"

    init(
        monitor: any USBMonitoring = USBMonitorFactory.makeMonitor(),
        makeNotificationCenter: @escaping @MainActor @Sendable () -> any NotificationCenterClient = {
            SystemNotificationCenter()
        },
        defaults: UserDefaults = .standard,
        loginItem: LoginItemController = LoginItemController(),
        alertWait: @escaping ConnectionAlertBatcher.Wait = { try await Task.sleep(for: .seconds(1)) }
    ) {
        self.monitor = monitor
        self.makeNotificationCenter = makeNotificationCenter
        self.defaults = defaults
        self.loginItem = loginItem
        self.alertWait = alertWait
        self.notificationsEnabled = defaults.object(forKey: Self.notificationsEnabledKey) as? Bool ?? false
        self.notificationSoundEnabled = defaults.bool(forKey: Self.notificationSoundEnabledKey)
        self.keepLatestResultPinned = defaults.object(forKey: Self.keepLatestResultPinnedKey) as? Bool ?? true
        self.showHubs = defaults.bool(forKey: Self.showHubsKey)
        bindMonitor()
    }

    var visibleDevices: [USBDevice] { showHubs ? currentDevices : currentDevices.filter { !$0.isHub } }
    var visibleHistory: [USBObservation] { showHubs ? history : history.filter { !$0.device.isHub } }
    var monitoringMessage: String? { monitoringStatus == .monitoring ? nil : monitoringStatus.message }
    var emptyDevicesMessage: String {
        guard monitoringStatus.isSnapshotReliable else { return "USB device information is unavailable or incomplete." }
        return currentDevices.isEmpty ? "No USB devices detected." : "USB hubs are hidden."
    }
    var latestConnectionStatus: String? {
        guard let device = latestConnectedDevice else { return nil }
        guard monitoringStatus.isSnapshotReliable else { return "Connection unconfirmed" }
        return currentDevices.contains { $0.id == device.id } ? "Connected" : "Disconnected"
    }
    var canRequestNotifications: Bool {
        switch notificationAuthorization {
        case .notDetermined, .failed: true
        case .authorized, .denied: false
        }
    }
    var notificationAuthorizationSummary: String {
        if isRequestingNotificationAuthorization { return "Waiting for notification permission…" }
        switch notificationAuthorization {
        case .authorized:
            return notificationsEnabled ? "Connection notifications are enabled." : "Connection notifications are off."
        case .denied: return "Notifications are disabled for usb-boop in System Settings → Notifications."
        case .notDetermined: return "Enable notifications to allow quiet connection banners."
        case .failed(let message): return "Could not enable notifications: \(message)"
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        notifier = ConnectionNotifier(center: makeNotificationCenter(), preferences: notificationPreferences)
        monitor.start()
        Task { [weak self] in await self?.refreshAuthorization() }
    }

    func stop() {
        hasStarted = false
        notifier = nil
        isRequestingNotificationAuthorization = false
        notificationAuthorization = .notDetermined
        alertBatcher.cancel()
        monitor.stop()
        alertedConnections.removeAll()
    }

    func refreshDevices() { monitor.refresh() }
    func reconcileAfterWake() { monitor.reconcileAfterWake() }
    func clearHistory() { history.removeAll() }

    func becameActive() {
        loginItem.refresh()
        Task { [weak self] in await self?.refreshAuthorization() }
    }

    func refreshAuthorization() async {
        guard let notifier else { return }
        let authorization = await notifier.authorization()
        guard hasStarted, self.notifier === notifier else { return }
        // A passive refresh must not hide why the user's last Enable action failed.
        switch (notificationAuthorization, authorization) {
        case (.failed, .notDetermined): break
        default: notificationAuthorization = authorization
        }
        if notificationAuthorization != .authorized { alertBatcher.cancel() }
    }

    /// Only UI actions call this method; restoring a saved preference never prompts.
    func setNotificationsEnabled(_ enabled: Bool) async {
        notificationsEnabled = enabled
        guard enabled, let notifier, !isRequestingNotificationAuthorization else { return }
        isRequestingNotificationAuthorization = true
        defer {
            if self.notifier === notifier { isRequestingNotificationAuthorization = false }
        }
        let authorization = await notifier.requestAuthorization()
        guard hasStarted, self.notifier === notifier else { return }
        notificationAuthorization = authorization
        if notificationAuthorization != .authorized { alertBatcher.cancel() }
    }

    /// Read by MenubarNotifier on every delivery, so turning the toggle off takes effect at once.
    private var notificationPreferences: @Sendable () -> NotificationPreferences {
        let store = ThreadSafeDefaults(defaults: defaults)
        return {
            NotificationPreferences(
                enabled: store.defaults.bool(forKey: AppModel.notificationsEnabledKey),
                soundEnabled: store.defaults.bool(forKey: AppModel.notificationSoundEnabledKey)
            )
        }
    }

    private func bindMonitor() {
        monitor.onStatusChanged = { [weak self] status in
            guard let self else { return }
            self.monitoringStatus = status
            if !status.isSnapshotReliable { self.alertBatcher.cancel() }
        }
        monitor.onDevicesChanged = { [weak self] devices in
            guard let self else { return }
            self.currentDevices = devices
            let identifiers = Set(devices.map(\.id))
            for identifier in self.alertedConnections.subtracting(identifiers) { self.alertBatcher.remove(identifier) }
            self.alertedConnections.formIntersection(identifiers)
            if let latest = self.latestConnectedDevice, let current = devices.first(where: { $0.id == latest.id }) {
                self.latestConnectedDevice = current
            }
        }
        monitor.onDeviceAttached = { [weak self] device in self?.receiveAttachment(device) }
        monitor.onDeviceDetached = { [weak self] device in
            self?.alertedConnections.remove(device.id)
            self?.alertBatcher.remove(device.id)
        }
        monitor.onObservation = { [weak self] observation in
            guard let self else { return }
            self.history.insert(observation, at: 0)
            if self.history.count > 50 { self.history.removeLast(self.history.count - 50) }
        }
    }

    private func deliverConnectionAlert(for devices: [USBDevice]) async {
        guard hasStarted, notificationsEnabled, let notifier else { return }
        // MenubarNotifier re-reads the toggle and re-checks permission before posting.
        let outcome = await notifier.deliver(devices)
        guard outcome == .notAuthorized, hasStarted, self.notifier === notifier else { return }
        await refreshAuthorization()
    }

    private func receiveAttachment(_ device: USBDevice) {
        latestConnectedDevice = device
        guard alertedConnections.insert(device.id).inserted else { return }
        guard hasStarted, notificationsEnabled, !device.isHub,
            notificationAuthorization == .authorized
        else { return }
        alertBatcher.enqueue(device)
    }
}

/// `UserDefaults` is documented as thread-safe, but Foundation does not mark it
/// `Sendable`. MenubarNotifier reads the preferences from its own task, so this
/// box only carries the reference there; it is never mutated.
private struct ThreadSafeDefaults: @unchecked Sendable {
    let defaults: UserDefaults
}

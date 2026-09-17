import Foundation
import Observation
import USBBoopKit

@MainActor
@Observable
final class AppModel {
    private(set) var monitoringStatus: USBMonitoringStatus = .stopped
    private(set) var currentDevices: [USBDevice] = []
    private(set) var latestConnectedDevice: USBDevice?
    private(set) var history: [USBObservation] = []
    private(set) var notificationAuthorization: UserNotificationCoordinator.AuthorizationState = .notDetermined
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
    private let makeNotifier: @MainActor @Sendable () -> UserNotificationCoordinator
    private var notifier: UserNotificationCoordinator?
    private let defaults: UserDefaults
    private let alertWait: ConnectionAlertBatcher.Wait
    private var hasStarted = false
    private var alertedConnections: Set<UInt64> = []
    @ObservationIgnored private lazy var alertBatcher = ConnectionAlertBatcher(wait: alertWait) { [weak self] devices in
        guard let self, self.hasStarted, self.notificationsEnabled, let notifier = self.notifier else { return }
        _ = await notifier.sendConnectionNotification(for: devices, soundEnabled: self.notificationSoundEnabled)
        guard self.hasStarted, self.notifier === notifier else { return }
        self.notificationAuthorization = notifier.authorizationState
    }

    static let notificationsEnabledKey = "notificationsEnabled"
    static let notificationSoundEnabledKey = "notificationSoundEnabled"
    static let keepLatestResultPinnedKey = "keepLatestResultPinned"
    static let showHubsKey = "showHubs"

    init(
        monitor: any USBMonitoring = USBMonitorFactory.makeMonitor(),
        makeNotifier: @escaping @MainActor @Sendable () -> UserNotificationCoordinator = { UserNotificationCoordinator() },
        defaults: UserDefaults = .standard,
        loginItem: LoginItemController = LoginItemController(),
        alertWait: @escaping ConnectionAlertBatcher.Wait = { try await Task.sleep(for: .seconds(1)) }
    ) {
        self.monitor = monitor
        self.makeNotifier = makeNotifier
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
        switch notificationAuthorization {
        case .authorized:
            return notificationsEnabled ? "Connection notifications are enabled." : "Connection notifications are off."
        case .denied: return "Notifications are disabled for usb-boop in System Settings → Notifications."
        case .notDetermined: return "Enable notifications to allow quiet connection banners."
        case .failed: return "Could not check or request notification permission. Try enabling notifications again."
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        notifier = makeNotifier()
        monitor.start()
        Task { [weak self] in await self?.refreshAuthorization() }
    }

    func stop() {
        hasStarted = false
        notifier = nil
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
        _ = await notifier.refreshAuthorizationState()
        guard hasStarted, self.notifier === notifier else { return }
        notificationAuthorization = notifier.authorizationState
        if notificationAuthorization != .authorized { alertBatcher.cancel() }
    }

    /// Only UI actions call this method; restoring a saved preference never prompts.
    func setNotificationsEnabled(_ enabled: Bool) async {
        notificationsEnabled = enabled
        guard enabled, let notifier else { return }
        _ = await notifier.requestAuthorizationIfNeeded()
        guard hasStarted, self.notifier === notifier else { return }
        notificationAuthorization = notifier.authorizationState
        if notificationAuthorization != .authorized { alertBatcher.cancel() }
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

    private func receiveAttachment(_ device: USBDevice) {
        latestConnectedDevice = device
        guard alertedConnections.insert(device.id).inserted else { return }
        guard hasStarted, notificationsEnabled, !device.isHub,
              notifier?.authorizationState == .authorized else { return }
        alertBatcher.enqueue(device)
    }
}

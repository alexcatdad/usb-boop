@testable import USBBoopKit
import UserNotifications
import XCTest

@MainActor
final class AppTestMockCenter: NotificationCenterProtocol {
    var mockStatus: UNAuthorizationStatus = .authorized
    var grantOnRequest = true
    var requestCount = 0
    var addedRequests: [UNNotificationRequest] = []
    func authorizationStatus() async -> UNAuthorizationStatus { mockStatus }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestCount += 1
        mockStatus = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }
    func add(_ request: UNNotificationRequest) async throws { addedRequests.append(request) }
}

@MainActor
final class AppModelTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "com.alexcatdad.usb-boop.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return defaults
    }

    private func makeModel(
        monitor: FixtureUSBMonitor = FixtureUSBMonitor(devices: []),
        center: AppTestMockCenter = AppTestMockCenter(),
        defaults: UserDefaults? = nil,
        wait: @escaping ConnectionAlertBatcher.Wait = { }
    ) -> AppModel {
        AppModel(monitor: monitor, makeNotifier: { UserNotificationCoordinator(center: center) },
                 defaults: defaults ?? self.defaults(), alertWait: wait)
    }

    func test_newInstallStartsQuietAndRestoresExistingPreferences() async {
        let store = defaults()
        let model = makeModel(defaults: store)
        XCTAssertFalse(model.notificationsEnabled)
        XCTAssertFalse(model.notificationSoundEnabled)
        XCTAssertTrue(model.keepLatestResultPinned)
        model.start()
        await model.setNotificationsEnabled(true)
        model.notificationSoundEnabled = true
        model.keepLatestResultPinned = false
        model.showHubs = true
        let restored = makeModel(defaults: store)
        XCTAssertTrue(restored.notificationsEnabled)
        XCTAssertTrue(restored.notificationSoundEnabled)
        XCTAssertFalse(restored.keepLatestResultPinned)
        XCTAssertTrue(restored.showHubs)
        model.stop()
    }

    func test_startAndActivationDoNotPromptOrInventActivity() async {
        let center = AppTestMockCenter()
        center.mockStatus = .notDetermined
        let monitor = FixtureUSBMonitor()
        let model = makeModel(monitor: monitor, center: center)
        model.start()
        await model.refreshAuthorization()
        model.becameActive()
        await model.refreshAuthorization()
        XCTAssertEqual(center.requestCount, 0)
        XCTAssertNil(model.latestConnectedDevice)
        XCTAssertTrue(model.history.isEmpty)
        XCTAssertFalse(model.currentDevices.isEmpty)
        XCTAssertTrue(model.currentDevices.allSatisfy { $0.connectedAt == nil })
        XCTAssertTrue(center.addedRequests.isEmpty)
        model.stop()
    }

    func test_savedEnabledPreferenceDoesNotPromptAtStartup() async {
        let center = AppTestMockCenter()
        center.mockStatus = .notDetermined
        let store = defaults()
        store.set(true, forKey: AppModel.notificationsEnabledKey)
        let model = makeModel(center: center, defaults: store)
        model.start()
        await model.refreshAuthorization()
        XCTAssertEqual(center.requestCount, 0)
        await model.setNotificationsEnabled(true)
        XCTAssertEqual(center.requestCount, 1)
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        model.stop()
    }

    func test_denialDoesNotRepeatedlyRequestPermission() async {
        let center = AppTestMockCenter()
        center.mockStatus = .notDetermined
        center.grantOnRequest = false
        let model = makeModel(center: center)
        model.start()
        await model.setNotificationsEnabled(true)
        await model.setNotificationsEnabled(true)
        XCTAssertEqual(center.requestCount, 1)
        XCTAssertEqual(model.notificationAuthorization, .denied)
        model.stop()
    }

    func test_connectionsBeforeAuthorizationAreNeverReplayed() async {
        let monitor = FixtureUSBMonitor(devices: [])
        let center = AppTestMockCenter()
        center.mockStatus = .notDetermined
        let model = makeModel(monitor: monitor, center: center)
        model.start()
        let device = USBDevice(id: 1, name: "Earlier", speed: .usb3Gen1)
        monitor.onDeviceAttached?(device)
        await model.setNotificationsEnabled(true)
        monitor.onDeviceAttached?(device)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(center.addedRequests.isEmpty)
        model.stop()
    }

    func test_hubsAndDuplicateCallbacksNeverMultiplyAlerts() async {
        var release: CheckedContinuation<Void, Never>?
        let monitor = FixtureUSBMonitor(devices: [])
        let center = AppTestMockCenter()
        let model = makeModel(monitor: monitor, center: center, wait: {
            await withCheckedContinuation { release = $0 }
        })
        model.start()
        await model.setNotificationsEnabled(true)
        let device = USBDevice(id: 1, name: "Device", speed: .usb3Gen1)
        monitor.onDeviceAttached?(device)
        await Task.yield()
        monitor.onDeviceAttached?(device)
        monitor.onDeviceAttached?(USBDevice(id: 2, name: "Hub", speed: .usb3Gen1, isHub: true))
        release?.resume()
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertNil(center.addedRequests.first?.content.sound)
        model.stop()
    }

    func test_disablingCancelsQueuedNotification() async {
        var release: CheckedContinuation<Void, Never>?
        let monitor = FixtureUSBMonitor(devices: [])
        let center = AppTestMockCenter()
        let model = makeModel(monitor: monitor, center: center, wait: {
            await withCheckedContinuation { release = $0 }
        })
        model.start()
        await model.setNotificationsEnabled(true)
        monitor.onDeviceAttached?(USBDevice(id: 1, name: "Device", speed: .usb3Gen1))
        await Task.yield()
        await model.setNotificationsEnabled(false)
        release?.resume()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(center.addedRequests.isEmpty)
        model.stop()
    }

    func test_permissionChangesAreReflectedOnRefresh() async {
        let center = AppTestMockCenter()
        let model = makeModel(center: center)
        model.start()
        await model.setNotificationsEnabled(true)
        center.mockStatus = .denied
        await model.refreshAuthorization()
        XCTAssertEqual(model.notificationAuthorization, .denied)
        XCTAssertTrue(model.notificationAuthorizationSummary.contains("System Settings"))
        model.stop()
    }

    func test_historyBoundFilteringClearingAndPrivacy() {
        let monitor = FixtureUSBMonitor(devices: [])
        let store = defaults()
        let model = makeModel(monitor: monitor, defaults: store)
        for index in 0..<55 {
            let device = USBDevice(id: UInt64(index), name: "Device \(index)", serialNumber: "private",
                                   speed: .usb3Gen1, isHub: index == 54)
            monitor.onObservation?(USBObservation(kind: .attached, device: device,
                                                  observedAt: Date(timeIntervalSince1970: Double(index))))
        }
        XCTAssertEqual(model.history.count, 50)
        XCTAssertEqual(model.history.first?.device.id, 54)
        XCTAssertEqual(model.history.last?.device.id, 5)
        XCTAssertTrue(model.history.allSatisfy { $0.device.serialNumber == nil })
        XCTAssertEqual(model.visibleHistory.count, 49)
        model.showHubs = true
        XCTAssertEqual(model.visibleHistory.count, 50)
        XCTAssertTrue(makeModel(defaults: store).history.isEmpty)
        model.clearHistory()
        XCTAssertTrue(model.history.isEmpty)
    }

    func test_emptyAndHiddenAndFailedStatesAreDistinct() {
        let monitor = FixtureUSBMonitor(devices: [])
        let model = makeModel(monitor: monitor)
        monitor.start()
        XCTAssertEqual(model.emptyDevicesMessage, "No USB devices detected.")
        monitor.onDevicesChanged?([USBDevice(id: 1, name: "Hub", speed: .usb3Gen1, isHub: true)])
        XCTAssertTrue(model.visibleDevices.isEmpty)
        XCTAssertEqual(model.emptyDevicesMessage, "USB hubs are hidden.")
        monitor.onStatusChanged?(.unavailable(.accessRestricted))
        XCTAssertTrue(model.emptyDevicesMessage.contains("unavailable"))
        model.showHubs = true
        XCTAssertEqual(model.visibleDevices.count, 1)
    }
}

import XCTest
import UserNotifications
@testable import USBBoopKit

/// Lightweight mock for testing AppModel's notification flow.
@MainActor
final class AppTestMockCenter: NotificationCenterProtocol, @unchecked Sendable {
    var mockStatus: UNAuthorizationStatus = .authorized
    var grantOnRequest = true
    var addedRequests: [UNNotificationRequest] = []

    func authorizationStatus() async -> UNAuthorizationStatus { mockStatus }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { grantOnRequest }
    func add(_ request: UNNotificationRequest) async throws { addedRequests.append(request) }
}

@MainActor
final class AppModelTests: XCTestCase {

    // nonisolated(unsafe) so setUp/tearDown (which are nonisolated) can access it.
    // All meaningful access happens from @MainActor test methods.
    private nonisolated(unsafe) var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.alexcatdad.usb-boop.tests.\(UUID().uuidString)")!
    }

    override func tearDown() {
        if let suiteName = testDefaults.volatileDomainNames.first {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        super.tearDown()
    }

    private func makeModel(
        monitor: any USBMonitoring = FixtureUSBMonitor(),
        defaults: UserDefaults? = nil,
        mockCenter: AppTestMockCenter? = nil
    ) -> AppModel {
        let center = mockCenter ?? AppTestMockCenter()
        return AppModel(
            monitor: monitor,
            makeNotifier: { UserNotificationCoordinator(center: center) },
            defaults: defaults ?? testDefaults
        )
    }

    // MARK: - Initialization

    func test_init_defaultState() {
        let model = makeModel()
        XCTAssertTrue(model.currentDevices.isEmpty)
        XCTAssertNil(model.latestConnectedDevice)
        XCTAssertTrue(model.notificationsEnabled)
        XCTAssertTrue(model.keepLatestResultPinned)
    }

    func test_init_readsNotificationsEnabledFromDefaults() {
        testDefaults.set(false, forKey: AppModel.notificationsEnabledKey)
        let model = makeModel()
        XCTAssertFalse(model.notificationsEnabled)
    }

    func test_init_readsKeepLatestResultPinnedFromDefaults() {
        testDefaults.set(false, forKey: AppModel.keepLatestResultPinnedKey)
        let model = makeModel()
        XCTAssertFalse(model.keepLatestResultPinned)
    }

    func test_init_defaultsToTrueWhenKeysAbsent() {
        // Ensure no values are set
        testDefaults.removeObject(forKey: AppModel.notificationsEnabledKey)
        testDefaults.removeObject(forKey: AppModel.keepLatestResultPinnedKey)
        let model = makeModel()
        XCTAssertTrue(model.notificationsEnabled)
        XCTAssertTrue(model.keepLatestResultPinned)
    }

    // MARK: - Computed properties (no device)

    func test_latestResultTitle_noDevice() {
        let model = makeModel()
        XCTAssertEqual(model.latestResultTitle, "Waiting for a USB device")
    }

    func test_latestResultDetail_noDevice() {
        let model = makeModel()
        XCTAssertEqual(
            model.latestResultDetail,
            "Plug in a device and usb-boop will surface the negotiated link speed here."
        )
    }

    // MARK: - Computed properties (with device via monitor callback)

    func test_latestResultTitle_withDevice() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        // Trigger monitor callbacks directly (bindMonitor already wired in init)
        fixture.start()
        XCTAssertNotNil(model.latestConnectedDevice)
        XCTAssertEqual(model.latestResultTitle, model.latestConnectedDevice!.notificationBody)
    }

    func test_latestResultDetail_withDevice() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        fixture.start()
        XCTAssertNotNil(model.latestConnectedDevice)
        XCTAssertEqual(model.latestResultDetail, model.latestConnectedDevice!.detailSummary)
    }

    // MARK: - Monitor callbacks via fixture.start()

    func test_fixtureStart_populatesDevices() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        fixture.start()
        XCTAssertFalse(model.currentDevices.isEmpty)
        XCTAssertEqual(model.currentDevices.count, PreviewFixtures.connectedDevices.count)
    }

    func test_fixtureStart_setsLatestConnectedDevice() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        fixture.start()
        XCTAssertNotNil(model.latestConnectedDevice)
    }

    func test_fixtureStart_latestDeviceIsFirst() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        fixture.start()
        // FixtureUSBMonitor fires onDeviceAttached with devices.first
        XCTAssertEqual(model.latestConnectedDevice, PreviewFixtures.connectedDevices.first)
    }

    func test_fixtureStart_isIdempotent() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        fixture.start()
        let devices1 = model.currentDevices
        fixture.start()
        let devices2 = model.currentDevices
        XCTAssertEqual(devices1, devices2)
    }

    // MARK: - Custom device list

    func test_emptyFixture_noDevicesAttached() {
        let fixture = FixtureUSBMonitor(devices: [])
        let model = makeModel(monitor: fixture)
        fixture.start()
        XCTAssertTrue(model.currentDevices.isEmpty)
        XCTAssertNil(model.latestConnectedDevice)
    }

    func test_singleDevice_setsLatestToThatDevice() {
        let device = USBDevice(
            id: 999,
            name: "Test Device",
            speed: .usb2High
        )
        let fixture = FixtureUSBMonitor(devices: [device])
        let model = makeModel(monitor: fixture)
        fixture.start()
        XCTAssertEqual(model.currentDevices.count, 1)
        XCTAssertEqual(model.latestConnectedDevice, device)
    }

    // MARK: - Persistence

    func test_notificationsEnabled_persistsToDefaults() {
        let model = makeModel()
        model.notificationsEnabled = false
        XCTAssertFalse(testDefaults.bool(forKey: AppModel.notificationsEnabledKey))
        model.notificationsEnabled = true
        XCTAssertTrue(testDefaults.bool(forKey: AppModel.notificationsEnabledKey))
    }

    func test_keepLatestResultPinned_persistsToDefaults() {
        let model = makeModel()
        model.keepLatestResultPinned = false
        XCTAssertFalse(testDefaults.bool(forKey: AppModel.keepLatestResultPinnedKey))
        model.keepLatestResultPinned = true
        XCTAssertTrue(testDefaults.bool(forKey: AppModel.keepLatestResultPinnedKey))
    }

    func test_notificationsEnabled_roundtrips() {
        let model = makeModel()
        model.notificationsEnabled = false

        // Create a second model reading from the same defaults
        let model2 = makeModel()
        XCTAssertFalse(model2.notificationsEnabled)
    }

    func test_keepLatestResultPinned_roundtrips() {
        let model = makeModel()
        model.keepLatestResultPinned = false

        let model2 = makeModel()
        XCTAssertFalse(model2.keepLatestResultPinned)
    }

    // MARK: - refreshDevices

    func test_refreshDevices_updatesSnapshot() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        fixture.start()
        let before = model.currentDevices
        model.refreshDevices()
        let after = model.currentDevices
        // Fixture provides same devices on refresh
        XCTAssertEqual(before.count, after.count)
    }

    func test_refreshDevices_withEmptyFixture() {
        let fixture = FixtureUSBMonitor(devices: [])
        let model = makeModel(monitor: fixture)
        fixture.start()
        model.refreshDevices()
        XCTAssertTrue(model.currentDevices.isEmpty)
    }

    // MARK: - onDevicesChanged callback

    func test_onDevicesChanged_updatesCurrentDevices() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        fixture.start()
        XCTAssertFalse(model.currentDevices.isEmpty)
    }

    // MARK: - onDeviceAttached callback

    func test_onDeviceAttached_updatesLatestDevice() {
        let fixture = FixtureUSBMonitor()
        let model = makeModel(monitor: fixture)
        fixture.start()
        XCTAssertNotNil(model.latestConnectedDevice)
    }

    // MARK: - notificationAuthorizationSummary

    func test_notificationAuthorizationSummary_initialValue() {
        let model = makeModel()
        XCTAssertEqual(model.notificationAuthorizationSummary, "Checking notification permission\u{2026}")
    }

    // MARK: - start() with mock notification center

    func test_start_populatesDevicesAndLatest() {
        let mock = AppTestMockCenter()
        mock.mockStatus = .authorized
        let model = makeModel(mockCenter: mock)
        model.start()
        XCTAssertFalse(model.currentDevices.isEmpty)
        XCTAssertNotNil(model.latestConnectedDevice)
    }

    func test_start_isIdempotent() {
        let mock = AppTestMockCenter()
        let model = makeModel(mockCenter: mock)
        model.start()
        let devices1 = model.currentDevices
        model.start() // second call ignored
        XCTAssertEqual(model.currentDevices, devices1)
    }

    func test_start_authorized_updatesSummary() async throws {
        let mock = AppTestMockCenter()
        mock.mockStatus = .authorized
        let model = makeModel(mockCenter: mock)
        model.start()
        // Allow async tasks (refreshNotificationAuthorization + requestNotificationsIfNeeded) to complete
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.notificationAuthorizationSummary, "Notifications are enabled.")
    }

    func test_start_denied_updatesSummary() async throws {
        let mock = AppTestMockCenter()
        mock.mockStatus = .denied
        let model = makeModel(mockCenter: mock)
        model.start()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.notificationAuthorizationSummary, "Notifications are disabled for usb-boop in macOS Notification Center.")
    }

    func test_start_notDetermined_andGranted_updatesSummary() async throws {
        let mock = AppTestMockCenter()
        mock.mockStatus = .notDetermined
        mock.grantOnRequest = true
        let model = makeModel(mockCenter: mock)
        model.start()
        try await Task.sleep(for: .milliseconds(100))
        // After request, status becomes authorized
        XCTAssertEqual(model.notificationAuthorizationSummary, "Notifications are enabled.")
    }

    func test_start_notDetermined_andDenied_updatesSummary() async throws {
        let mock = AppTestMockCenter()
        mock.mockStatus = .notDetermined
        mock.grantOnRequest = false
        let model = makeModel(mockCenter: mock)
        model.start()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.notificationAuthorizationSummary, "Notifications are disabled for usb-boop in macOS Notification Center.")
    }

    // MARK: - Notification sending via start()

    func test_start_withNotificationsEnabled_sendsNotification() async throws {
        let mock = AppTestMockCenter()
        mock.mockStatus = .authorized
        let model = makeModel(mockCenter: mock)
        model.notificationsEnabled = true
        model.start()
        // FixtureUSBMonitor fires onDeviceAttached during start
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(mock.addedRequests.isEmpty, "Should have sent a notification for the attached device")
    }

    func test_start_withNotificationsDisabled_doesNotSendNotification() async throws {
        let mock = AppTestMockCenter()
        mock.mockStatus = .authorized
        let model = makeModel(mockCenter: mock)
        model.notificationsEnabled = false
        model.start()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(mock.addedRequests.isEmpty, "Should NOT send notification when disabled")
    }

    // MARK: - Static key constants

    func test_notificationsEnabledKey_value() {
        XCTAssertEqual(AppModel.notificationsEnabledKey, "notificationsEnabled")
    }

    func test_keepLatestResultPinnedKey_value() {
        XCTAssertEqual(AppModel.keepLatestResultPinnedKey, "keepLatestResultPinned")
    }
}

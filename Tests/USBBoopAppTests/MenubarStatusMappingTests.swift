import MenubarKit
@testable import USBBoopKit
import XCTest

@MainActor
final class MenubarStatusMappingTests: XCTestCase {
    func test_healthyMonitoringIsOKAndCountsDevices() {
        XCTAssertEqual(MenubarStatus.usbBoop(.monitoring, deviceCount: 0),
                       MenubarStatus(tone: .ok, word: "Monitoring", headline: "Monitoring USB",
                                     detail: "No USB devices connected"))
        XCTAssertEqual(MenubarStatus.usbBoop(.monitoring, deviceCount: 1).detail, "1 device connected")
        XCTAssertEqual(MenubarStatus.usbBoop(.monitoring, deviceCount: 3).detail, "3 devices connected")
        XCTAssertFalse(MenubarStatus.usbBoop(.starting, deviceCount: 0).tone.needsAttention)
    }

    func test_problemsBadgeTheTrayAndExplainTheIssue() {
        let cases: [(USBMonitoringStatus, StatusTone)] = [
            (.degraded(.incompleteResults), .warning),
            (.unavailable(.registrationFailed), .error),
            (.stopped, .off),
        ]
        for (monitoring, tone) in cases {
            let status = MenubarStatus.usbBoop(monitoring, deviceCount: 2)
            XCTAssertEqual(status.tone, tone)
            XCTAssertTrue(status.tone.needsAttention)
            XCTAssertEqual(status.detail, monitoring.message)
        }
    }

    func test_trayVoiceOverLabelNamesAppAndStatus() {
        let status = MenubarStatus.usbBoop(.unavailable(.registrationFailed), deviceCount: 0)
        XCTAssertEqual(TrayAccessibility.label(appName: "usb-boop", statusWord: status.word),
                       "usb-boop, Monitoring unavailable")
    }

    func test_modelStatusCountsOnlyVisibleDevices() {
        let monitor = FixtureUSBMonitor(devices: [
            USBDevice(id: 1, name: "Drive", speed: .usb3Gen2),
            USBDevice(id: 2, name: "Hub", speed: .usb3Gen1, isHub: true),
        ])
        let suite = "com.alexcatdad.usb-boop.status-tests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = AppModel(monitor: monitor, defaults: UserDefaults(suiteName: suite) ?? .standard)
        monitor.start()
        XCTAssertEqual(model.status.detail, "1 device connected")
        model.showHubs = true
        XCTAssertEqual(model.status.detail, "2 devices connected")
    }
}

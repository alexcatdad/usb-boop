@testable import USBBoopKit
import XCTest

@MainActor
final class USBMonitorFactoryTests: XCTestCase {

    func test_makeMonitor_default_returnsIOKitMonitor() {
        // In the test environment without USB_BOOP_USE_FIXTURES, should return real monitor
        let saved = ProcessInfo.processInfo.environment["USB_BOOP_USE_FIXTURES"]
        if saved == "1" {
            // If somehow set, this test can't run meaningfully
            return
        }
        let monitor = USBMonitorFactory.makeMonitor()
        XCTAssertTrue(monitor is IOKitUSBMonitor)
    }

    func test_makeMonitor_withFixtureEnv_returnsFixture() {
        setenv("USB_BOOP_USE_FIXTURES", "1", 1)
        let monitor = USBMonitorFactory.makeMonitor()
        unsetenv("USB_BOOP_USE_FIXTURES")
        XCTAssertTrue(monitor is FixtureUSBMonitor)
    }
}

import XCTest
import UserNotifications
@testable import USBBoopKit

// NOTE: UNUserNotificationCenter is a concrete class that cannot be subclassed
// or easily mocked. The coordinator's methods (requestAuthorizationIfNeeded,
// refreshAuthorizationState, sendConnectionNotification) all go through the
// real notification center, which requires a running host app with a bundle
// identifier. In a unit-test bundle without a host app, calling
// UNUserNotificationCenter.current() and querying notification settings may
// behave unpredictably or hang.
//
// What we CAN test:
// - The initializer accepts a custom centerProvider closure.
// - The AuthorizationState enum exists and has the expected cases.
//
// What we CANNOT reliably test without a protocol abstraction:
// - requestAuthorizationIfNeeded() behavior (requires real notification center)
// - refreshAuthorizationState() behavior (requires real notification center)
// - sendConnectionNotification(for:) side effects
//
// To make this class fully testable, a future refactor could introduce a
// protocol (e.g., NotificationCenterProviding) that wraps the notification
// center's API, allowing a mock to be injected in tests.

@MainActor
final class UserNotificationCoordinatorTests: XCTestCase {

    func test_authorizationState_hasExpectedCases() {
        // Verify all three cases exist and are distinct.
        let notDetermined = UserNotificationCoordinator.AuthorizationState.notDetermined
        let denied = UserNotificationCoordinator.AuthorizationState.denied
        let authorized = UserNotificationCoordinator.AuthorizationState.authorized

        // They should all be different from each other (Sendable enum, pattern-match).
        switch notDetermined {
        case .notDetermined: break
        default: XCTFail("Expected .notDetermined")
        }

        switch denied {
        case .denied: break
        default: XCTFail("Expected .denied")
        }

        switch authorized {
        case .authorized: break
        default: XCTFail("Expected .authorized")
        }
    }

    func test_init_acceptsCustomCenterProvider() {
        // Verify that the coordinator can be created with a custom provider
        // closure without crashing. We do NOT call any methods that would
        // invoke the center, since we cannot provide a valid mock.
        var providerCalled = false
        let _ = UserNotificationCoordinator(centerProvider: {
            providerCalled = true
            return UNUserNotificationCenter.current()
        })

        // The provider should not be called during init -- only when a method
        // accesses the center.
        XCTAssertFalse(providerCalled, "centerProvider should be lazy; not called during init")
    }
}

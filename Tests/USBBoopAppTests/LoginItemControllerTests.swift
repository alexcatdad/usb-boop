import Foundation
import XCTest

@MainActor
private final class TestLoginItemService: LoginItemService {
    var status: LoginItemStatus = .off
    var registrationResult: LoginItemStatus = .enabled
    var registerError: Error?
    var unregisterError: Error?
    var registerCount = 0
    var unregisterCount = 0
    var settingsCount = 0
    var onUnregister: (() async -> Void)?

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        status = registrationResult
    }

    func unregister() async throws {
        unregisterCount += 1
        await onUnregister?()
        if let unregisterError { throw unregisterError }
        status = .off
    }

    func openSystemSettings() {
        settingsCount += 1
    }
}

@MainActor
final class LoginItemControllerTests: XCTestCase {
    func testInitAndRefreshReadActualStatusWithoutRegistering() {
        let service = TestLoginItemService()
        service.status = .enabled
        let controller = LoginItemController(service: service)
        XCTAssertTrue(controller.isEnabled)
        for status: LoginItemStatus in [.off, .enabled, .requiresApproval, .unavailable] {
            service.status = status
            controller.refresh()
            XCTAssertEqual(controller.status, status)
            XCTAssertEqual(controller.isEnabled, status == .enabled)
        }
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(service.unregisterCount, 0)
    }

    func testEnableRegistersOnceAndUsesResultingStatus() async {
        let service = TestLoginItemService()
        let controller = LoginItemController(service: service)
        await controller.setEnabled(true)
        await controller.setEnabled(true)
        XCTAssertEqual(service.registerCount, 1)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.errorMessage)
        XCTAssertFalse(controller.isUpdating)
    }

    func testPendingApprovalDoesNotClaimEnabledOrRegisterAgain() async {
        let service = TestLoginItemService()
        service.registrationResult = .requiresApproval
        let controller = LoginItemController(service: service)
        await controller.setEnabled(true)
        await controller.setEnabled(true)
        controller.refresh()
        XCTAssertEqual(controller.status, .requiresApproval)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(service.registerCount, 1)
    }

    func testDisableUnregistersEnabledAndPendingServices() async {
        for status: LoginItemStatus in [.enabled, .requiresApproval] {
            let service = TestLoginItemService()
            service.status = status
            let controller = LoginItemController(service: service)
            await controller.setEnabled(false)
            await controller.setEnabled(false)
            XCTAssertEqual(service.unregisterCount, 1)
            XCTAssertEqual(controller.status, .off)
        }
    }

    func testRegistrationFailureKeepsActualStatusAndExposesError() async throws {
        let service = TestLoginItemService()
        service.registerError = NSError(domain: "LoginItemTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Registration denied"
        ])
        let controller = LoginItemController(service: service)
        await controller.setEnabled(true)
        controller.refresh()
        XCTAssertEqual(controller.status, .off)
        XCTAssertTrue(try XCTUnwrap(controller.errorMessage).contains("Registration denied"))
        XCTAssertEqual(service.registerCount, 1)
        XCTAssertFalse(controller.isUpdating)

        service.registerError = nil
        await controller.setEnabled(true)
        XCTAssertNil(controller.errorMessage)
        XCTAssertTrue(controller.isEnabled)
    }

    func testUnregistrationFailureKeepsActualStatusAndExposesError() async throws {
        let service = TestLoginItemService()
        service.status = .enabled
        service.unregisterError = NSError(domain: "LoginItemTests", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Removal failed"
        ])
        let controller = LoginItemController(service: service)
        await controller.setEnabled(false)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertTrue(try XCTUnwrap(controller.errorMessage).contains("Removal failed"))
        XCTAssertFalse(controller.isUpdating)
    }

    func testMutationInFlightPreventsOverlappingRegistration() async {
        let service = TestLoginItemService()
        service.status = .enabled
        let controller = LoginItemController(service: service)
        service.onUnregister = {
            XCTAssertTrue(controller.isUpdating)
            await controller.setEnabled(true)
        }
        await controller.setEnabled(false)
        XCTAssertEqual(service.unregisterCount, 1)
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(controller.status, .off)
    }

    func testSettingsOpensOnlyOnExplicitAction() {
        let service = TestLoginItemService()
        service.status = .requiresApproval
        let controller = LoginItemController(service: service)
        controller.refresh()
        XCTAssertEqual(service.settingsCount, 0)
        controller.openSystemSettings()
        XCTAssertEqual(service.settingsCount, 1)
        XCTAssertEqual(service.registerCount, 0)
    }
}

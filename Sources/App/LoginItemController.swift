import Foundation
import Observation
import ServiceManagement

enum LoginItemStatus: Equatable {
    case off
    case enabled
    case requiresApproval
    case unavailable

    var summary: String {
        switch self {
        case .off: "Launch at login is off."
        case .enabled: "usb-boop will launch when you log in."
        case .requiresApproval: "Allow usb-boop in System Settings → Login Items to launch at login."
        case .unavailable: "Launch at login is unavailable for this app installation."
        }
    }
}

@MainActor
protocol LoginItemService {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() async throws
    func openSystemSettings()
}

@MainActor
struct SystemLoginItemService: LoginItemService {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: .off
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() async throws {
        try await SMAppService.mainApp.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
@Observable
final class LoginItemController {
    private(set) var status: LoginItemStatus
    private(set) var errorMessage: String?
    private(set) var isUpdating = false
    private let service: any LoginItemService

    var isEnabled: Bool { status == .enabled }

    init(service: any LoginItemService = SystemLoginItemService()) {
        self.service = service
        self.status = service.status
    }

    /// Refreshing is read-only: registration always requires an explicit user action.
    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer {
            refresh()
            isUpdating = false
        }
        errorMessage = nil
        refresh()

        do {
            if enabled {
                // Pending approval is already registered; never bypass or repeatedly request approval.
                guard status != .enabled, status != .requiresApproval else { return }
                try service.register()
            } else {
                guard status == .enabled || status == .requiresApproval else { return }
                try await service.unregister()
            }
        } catch {
            let action = enabled ? "enable" : "disable"
            errorMessage = "Could not \(action) launch at login: \(error.localizedDescription)"
        }
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }
}

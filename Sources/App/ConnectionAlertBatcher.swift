import Foundation
import USBBoopKit

/// A fixed window from the first connection; later events never extend it.
@MainActor
final class ConnectionAlertBatcher {
    typealias Wait = @MainActor () async throws -> Void
    private let wait: Wait
    private let deliver: @MainActor ([USBDevice]) async -> Void
    private var pending: [USBDevice] = []
    private var task: Task<Void, Never>?
    private struct Delivery {
        let deviceIDs: Set<UInt64>
        let task: Task<Void, Never>
    }
    private var deliveries: [UUID: Delivery] = [:]

    init(
        wait: @escaping Wait = { try await Task.sleep(for: .seconds(1)) },
        deliver: @escaping @MainActor ([USBDevice]) async -> Void
    ) {
        self.wait = wait
        self.deliver = deliver
    }

    func enqueue(_ device: USBDevice) {
        guard !device.isHub, !pending.contains(where: { $0.id == device.id }) else { return }
        pending.append(device)
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do { try await wait() } catch { return }
            guard !Task.isCancelled else { return }
            let devices = pending
            pending.removeAll()
            task = nil
            guard !devices.isEmpty else { return }
            let identifier = UUID()
            let delivery = Task { [weak self] in
                guard let self, !Task.isCancelled else { return }
                await deliver(devices)
                deliveries[identifier] = nil
            }
            deliveries[identifier] = Delivery(deviceIDs: Set(devices.map(\.id)), task: delivery)
        }
    }

    func remove(_ identifier: UInt64) {
        pending.removeAll { $0.id == identifier }
        // Prefer dropping the whole group to announcing a device already disconnected.
        let affected = deliveries.filter { $0.value.deviceIDs.contains(identifier) }
        for (key, delivery) in affected {
            delivery.task.cancel()
            deliveries[key] = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        pending.removeAll()
        for delivery in deliveries.values { delivery.task.cancel() }
        deliveries.removeAll()
    }
}

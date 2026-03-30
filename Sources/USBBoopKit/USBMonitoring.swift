import Foundation

@MainActor
public protocol USBMonitoring: AnyObject {
    var onDevicesChanged: (([USBDevice]) -> Void)? { get set }
    var onDeviceAttached: ((USBDevice) -> Void)? { get set }

    func start()
    func stop()
    func refresh()
}

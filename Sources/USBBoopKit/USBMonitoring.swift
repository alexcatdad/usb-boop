import Foundation

@MainActor
public protocol USBMonitoring: AnyObject {
    var onDevicesChanged: (@MainActor ([USBDevice]) -> Void)? { get set }
    var onDeviceAttached: (@MainActor (USBDevice) -> Void)? { get set }

    func start()
    func stop()
    func refresh()
}

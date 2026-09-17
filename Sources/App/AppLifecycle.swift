import AppKit

/// AppKit owns these observers for the app's lifetime; callbacks run on the main thread.
@MainActor
final class AppLifecycle: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    @objc private func didWake() {
        model?.reconcileAfterWake()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        model?.stop()
    }
}

import UIKit
import ExternalAccessory

final class AppDelegate: NSObject, UIApplicationDelegate {

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryConnected(_:)),
            name: .EAAccessoryDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDisconnected(_:)),
            name: .EAAccessoryDidDisconnect,
            object: nil
        )
        EAAccessoryManager.shared().registerForLocalNotifications()
        return true
    }

    @objc private func accessoryConnected(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
        NotificationCenter.default.post(
            name: .cameraAccessoryConnected,
            object: accessory
        )
    }

    @objc private func accessoryDisconnected(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
        NotificationCenter.default.post(
            name: .cameraAccessoryDisconnected,
            object: accessory
        )
    }

    func beginTransferBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "CameraTransfer") {
            self.endTransferBackgroundTask()
        }
    }

    func endTransferBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

extension Notification.Name {
    static let cameraAccessoryConnected = Notification.Name("CameraAccessoryConnected")
    static let cameraAccessoryDisconnected = Notification.Name("CameraAccessoryDisconnected")
}

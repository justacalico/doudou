import Flutter
import UIKit

/// Thin wrapper over UIApplication.beginBackgroundTask so Dart can hold the
/// process alive across track transitions. While the screen is locked the
/// app only stays running because audio is playing; the gap between one
/// source stopping and the next one starting is enough for iOS to suspend
/// the process mid-transition, which wedges playback. Holding a background
/// task through that gap keeps the platform channel and the loopback stream
/// proxy running until the next song is actually outputting audio.
final class BackgroundTaskPlugin: NSObject, FlutterPlugin {
    static let channelName = "gitlab.openlyst.doudou/background_task"

    private var handleToTask: [Int: UIBackgroundTaskIdentifier] = [:]
    private var nextHandle = 1

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BackgroundTaskPlugin()
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "begin":
            let name = (call.arguments as? [String: Any])?["name"] as? String ?? "background-task"
            result(beginTask(name: name))
        case "end":
            if let args = call.arguments as? [String: Any], let handle = args["id"] as? Int {
                endTask(handle)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func beginTask(name: String) -> Int {
        var taskId = UIBackgroundTaskIdentifier.invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            // The grant expired while still open: ending it here is required,
            // otherwise iOS kills the process instead of suspending it.
            UIApplication.shared.endBackgroundTask(taskId)
            self?.dropTask(taskId)
        }
        guard taskId != .invalid else { return -1 }
        let handle = nextHandle
        nextHandle += 1
        handleToTask[handle] = taskId
        return handle
    }

    private func dropTask(_ taskId: UIBackgroundTaskIdentifier) {
        if let entry = handleToTask.first(where: { $0.value == taskId }) {
            handleToTask.removeValue(forKey: entry.key)
        }
    }

    private func endTask(_ handle: Int) {
        guard let taskId = handleToTask.removeValue(forKey: handle) else { return }
        UIApplication.shared.endBackgroundTask(taskId)
    }
}

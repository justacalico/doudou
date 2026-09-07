import Flutter
import MediaPlayer

/// Shows a heart button in the iOS lock screen / Control Center Now Playing
/// controls via MPRemoteCommandCenter's likeCommand. Tapping it forwards an
/// `onFavoritePressed` call to Dart; Dart pushes the current favourite state
/// back through `setFavoriteState` so the indicator stays in sync.
final class FavoriteCommandPlugin: NSObject, FlutterPlugin {
    static let channelName = "gitlab.openlyst.doudou/lockscreen_favorite"

    private var channel: FlutterMethodChannel?
    private var targetAdded = false

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FavoriteCommandPlugin()
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setFavoriteState":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(
                    code: "bad_args",
                    message: "setFavoriteState expects a map",
                    details: nil
                ))
                return
            }
            apply(
                enabled: args["enabled"] as? Bool ?? false,
                active: args["active"] as? Bool ?? false
            )
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func apply(enabled: Bool, active: Bool) {
        // audio_service disables the feedback commands when it first
        // activates the command center, so every state push has to
        // re-enable the like command.
        let command = MPRemoteCommandCenter.shared().likeCommand
        if enabled {
            if !targetAdded {
                command.addTarget(self, action: #selector(onLikeCommand(_:)))
                targetAdded = true
            }
            command.isActive = active
            command.isEnabled = true
        } else {
            command.isEnabled = false
            command.isActive = false
            if targetAdded {
                command.removeTarget(self)
                targetAdded = false
            }
        }
    }

    @objc private func onLikeCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        channel?.invokeMethod("onFavoritePressed", arguments: nil)
        return .success
    }
}

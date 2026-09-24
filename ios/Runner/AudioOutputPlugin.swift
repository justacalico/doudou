import AVFoundation
import AVKit
import Flutter

/// iOS does not let apps pick an arbitrary output route in code. What is
/// possible: toggling the built-in receiver/speaker override through
/// AVAudioSession.overrideOutputAudioPort, and presenting the system route
/// picker (AVRoutePickerView) so the user can choose the target themselves.
/// Non built-in routes are therefore reported as selectable=false and the UI
/// offers the picker instead.
final class AudioOutputPlugin: NSObject, FlutterPlugin {
    static let channelName = "gitlab.openlyst.doudou/audio_output"

    private static let speakerId = "builtin:speaker"
    private static let receiverId = "builtin:receiver"

    /// Kept alive across calls: on iPad the picker presents as a popover
    /// anchored to this view, so removing it would dismiss the popover.
    private var routePicker: AVRoutePickerView?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AudioOutputPlugin()
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDevices":
            result(devices())
        case "selectDevice":
            let args = call.arguments as? [String: Any]
            result(select(id: args?["id"] as? String))
        case "showSystemPicker":
            result(showRoutePicker())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func devices() -> [[String: Any]] {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let builtInOnly = !outputs.isEmpty && outputs.allSatisfy {
            $0.portType == .builtInReceiver || $0.portType == .builtInSpeaker
        }
        if builtInOnly {
            let onSpeaker = outputs.contains { $0.portType == .builtInSpeaker }
            return [
                [
                    "id": Self.receiverId,
                    "name": UIDevice.current.name,
                    "kind": "earpiece",
                    "selected": !onSpeaker,
                    "selectable": true,
                ],
                [
                    "id": Self.speakerId,
                    "name": "Speaker",
                    "kind": "speaker",
                    "selected": onSpeaker,
                    "selectable": true,
                ],
            ]
        }
        return outputs.map { port in
            [
                "id": port.uid,
                "name": port.portName,
                "kind": kind(for: port.portType),
                "selected": true,
                "selectable": false,
            ]
        }
    }

    private func kind(for portType: AVAudioSession.Port) -> String {
        switch portType {
        case .builtInSpeaker:
            return "speaker"
        case .builtInReceiver:
            return "earpiece"
        case .headphones, .headsetMic, .lineOut:
            return "wired"
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return "bluetooth"
        case .airPlay:
            return "airplay"
        case .usbAudio:
            return "usb"
        case .hdmi:
            return "hdmi"
        default:
            return "other"
        }
    }

    private func select(id: String?) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            switch id {
            case Self.speakerId:
                try session.overrideOutputAudioPort(.speaker)
            case Self.receiverId:
                try session.overrideOutputAudioPort(.none)
            default:
                return false
            }
            return true
        } catch {
            return false
        }
    }

    private func showRoutePicker() -> Bool {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
                ?? UIApplication.shared.windows.first
        else {
            return false
        }

        let picker = routePicker ?? AVRoutePickerView(
            frame: CGRect(x: -100, y: -100, width: 1, height: 1)
        )
        if picker.superview == nil {
            picker.alpha = 0.01
            window.addSubview(picker)
            routePicker = picker
        }

        // A2DP/AirPlay targets only appear if the session options allow them.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            session.category,
            options: session.categoryOptions.union([.allowBluetoothA2dp, .allowAirPlay])
        )

        DispatchQueue.main.async {
            for view in picker.subviews where view is UIButton {
                (view as! UIButton).sendActions(for: .touchUpInside)
                break
            }
        }
        return true
    }
}

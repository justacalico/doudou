import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(NSRect(x: 0, y: 0, width: 1024, height: 640), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    setupWindowControlChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func setupWindowControlChannel(_ flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.openlyst.doudou/window_controls",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(FlutterError(code: "NO_WINDOW", message: "No window found", details: nil))
        return
      }

      switch call.method {
      case "minimize":
        self.miniaturize(nil)
        result(nil)
      case "maximize":
        if self.styleMask.contains(.fullScreen) {
          self.toggleFullScreen(nil)
        } else {
          self.zoom(nil)
        }
        result(nil)
      case "close":
        self.close()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: false)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // doudou-server is a headless CLI. Keep the window off-screen and
    // invisible; the Dart side never mounts a widget tree and exits when
    // the requested CLI command finishes.
    self.setIsVisible(false)
    self.canHide = true

    super.awakeFromNib()
  }
}

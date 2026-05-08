import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = NSApp.windows.first {
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.styleMask = [.fullSizeContentView, .titled, .closable, .miniaturizable, .resizable]
      window.isMovableByWindowBackground = true
      window.standardWindowButton(.closeButton)?.isHidden = true
      window.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    super.applicationDidFinishLaunching(notification)
    
    setupWindowControlChannel()
  }
  
  private func setupWindowControlChannel() {
    guard let window = NSApp.windows.first,
          let flutterViewController = window.contentViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "com.openlyst.doudou/window_controls",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let window = NSApp.windows.first else {
        result(FlutterError(code: "NO_WINDOW", message: "No window found", details: nil))
        return
      }
      
      switch call.method {
      case "minimize":
        window.miniaturize(nil)
        result(nil)
      case "maximize":
        if window.styleMask.contains(.fullScreen) {
          window.toggleFullScreen(nil)
        } else {
          window.zoom(nil)
        }
        result(nil)
      case "close":
        window.close()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

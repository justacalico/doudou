import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in sender.windows {
        window.makeKeyAndOrderFront(self)
      }
    }
    return true
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
  }
}

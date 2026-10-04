import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  static var isServerMode: Bool {
    ProcessInfo.processInfo.arguments.contains("-server")
  }

  private var headlessEngine: FlutterEngine?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if AppDelegate.isServerMode {
      return true
    }
    if !flag {
      for window in sender.windows {
        window.makeKeyAndOrderFront(self)
      }
    }
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if AppDelegate.isServerMode {
      // -server runs the sync server headless: no window, no dock icon. The
      // Dart side detects the flag from the process arguments itself.
      NSApp.setActivationPolicy(.accessory)
      for window in NSApp.windows {
        window.orderOut(nil)
      }
      let engine = FlutterEngine(name: "doudou-server")
      engine.run(withEntrypoint: nil)
      headlessEngine = engine
      return
    }

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

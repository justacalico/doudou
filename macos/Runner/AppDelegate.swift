import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // The sandbox remaps TMPDIR to the app's container, which prevents
    // flutter_discord_rpc from finding Discord's IPC socket. Grab the real
    // system temp dir via confstr and override TMPDIR before Flutter starts.
    var buf = [CChar](repeating: 0, count: 1024)
    confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count)
    if let realTmp = String(cString: buf, encoding: .utf8), !realTmp.isEmpty {
      setenv("TMPDIR", realTmp, 1)
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

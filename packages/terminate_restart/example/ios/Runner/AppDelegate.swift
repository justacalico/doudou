import UIKit
import Flutter
import terminate_restart

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Handle our custom URL scheme
        if url.scheme == Bundle.main.bundleIdentifier {
            // App was relaunched
            return true
        }
        return false
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        // Clean up any observers or resources if needed
        super.applicationWillTerminate(application)
    }
}

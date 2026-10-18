import SwiftUI
import UIKit

private final class AirCard17AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: UIApplication,
                     shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        false
    }
}

private enum LaunchStateCleanup {
    static func removeIfPresent(at path: String) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            return
        }

        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            NSLog("AirCard17: failed to remove stale launch state at %@: %@", path, error.localizedDescription)
        }
    }

    static func purgeStaleUIState() {
        guard let libraryDirectory = NSSearchPathForDirectoriesInDomains(
            .libraryDirectory,
            .userDomainMask,
            true
        ).first else {
            return
        }

        let stalePaths = [
            (libraryDirectory as NSString).appendingPathComponent("Saved Application State"),
            (libraryDirectory as NSString).appendingPathComponent("SplashBoard")
        ]

        stalePaths.forEach(removeIfPresent)
    }
}

/// AirCard17 entry point.
@main
struct AirCard17App: App {
    @UIApplicationDelegateAdaptor(AirCard17AppDelegate.self) private var appDelegate

    init() {
        LaunchStateCleanup.purgeStaleUIState()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

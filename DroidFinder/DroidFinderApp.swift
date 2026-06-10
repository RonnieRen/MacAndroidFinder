import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        assignSelfAsDelegateToAllWindows()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMainNotification(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        // Clean up any leftover temp files from a previous session
        cleanupDroidFinderTempDir()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanupDroidFinderTempDir()
    }

    private func cleanupDroidFinderTempDir() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DroidFinder")
        try? FileManager.default.removeItem(at: tempDir)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }

    @objc
    private func windowDidBecomeMainNotification(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        window.delegate = self
    }

    private func assignSelfAsDelegateToAllWindows() {
        for window in NSApp.windows {
            window.delegate = self
        }
    }
}

@main
struct DroidFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = DroidFinderViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 560)
        }
    }
}

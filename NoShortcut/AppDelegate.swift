import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a pure menu bar / background agent (no Dock icon, no Cmd-Tab entry)
        NSApp.setActivationPolicy(.accessory)

        // Optional: prevent the app from terminating when the last window is closed.
        // (We already control windows manually.)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app running even if the user closes all windows.
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Best effort cleanup happens inside ProfileStore / ShortcutDisabler.
    }
}
import SwiftUI

@main
struct NoShortcutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProfileStore()

    var body: some Scene {
        // The menu bar / status item
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            MenuBarIcon(store: store)
        }
        .menuBarExtraStyle(.window)

        // The "Manage Profiles" window
        Window("Manage Profiles", id: "manage-profiles") {
            ProfileManagerView(store: store)
                .frame(minWidth: 620, minHeight: 440)
        }
        .defaultSize(width: 680, height: 480)
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
    }
}
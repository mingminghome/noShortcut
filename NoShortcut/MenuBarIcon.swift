import SwiftUI

struct MenuBarIcon: View {
    @ObservedObject var store: ProfileStore

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(store.isEnabled ? .orange : .primary)
            .help(store.menuBarStatusSummary)
    }

    private var iconName: String {
        store.isEnabled ? "command.circle.fill" : "command.circle"
    }
}
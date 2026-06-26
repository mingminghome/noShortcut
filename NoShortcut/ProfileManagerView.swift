import SwiftUI
import AppKit

struct ProfileManagerView: View {
    @ObservedObject var store: ProfileStore

    @State private var selectedProfileID: UUID?
    @State private var showingAddProfileSheet = false
    @State private var newProfileName = ""
    @State private var newProfileBlockingMode: ProfileBlockingMode = .selectedOnly
    @State private var showingRecorder = false
    @State private var showingAddShortcutSheet = false

    private var selectedProfile: Profile? {
        guard let id = selectedProfileID else { return nil }
        return store.profiles.first { $0.id == id }
    }

    private typealias BlockingChoice = ProfileBlockingMode

    var body: some View {
        NavigationSplitView {
            // Sidebar: list of profiles
            List(store.profiles, id: \.id, selection: $selectedProfileID) { profile in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                        Text(profileSubtitle(profile))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if profile.id == store.activeProfileId {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(profile.id)
                .contextMenu {
                    Button("Rename") { rename(profile) }
                    Button("Delete", role: .destructive) {
                        store.deleteProfile(profile)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Profiles")

            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        newProfileName = "New Profile"
                        newProfileBlockingMode = .selectedOnly
                        showingAddProfileSheet = true
                    } label: {
                        Label("Add Profile", systemImage: "plus")
                    }
                    .help("Create a new profile")
                }
            }

        } detail: {
            if let profile = selectedProfile {
                ScrollView {
                    Form {
                        profileSummarySection(profile)
                        blockingModeSection(profile)

                        switch profile.blockingMode {
                        case .all:
                            allShortcutsSection
                        case .selectedOnly, .allExcept:
                            if profile.blockingMode == .allExcept {
                                allExceptSummarySection
                            }
                            shortcutsListSection(profile)
                        }
                    }
                    .formStyle(.grouped)
                    .scrollDisabled(true)
                }
                .navigationTitle(profile.name)
                .toolbar {
                    if profile.usesShortcutList {
                        ToolbarItem {
                            Button {
                                showingAddShortcutSheet = true
                            } label: {
                                Label("Add Shortcut", systemImage: "plus")
                            }
                            .help("Browse common and system shortcuts")
                        }

                        ToolbarItem {
                            Menu {
                                Button {
                                    showingRecorder = true
                                } label: {
                                    Label("Record Custom Shortcut…", systemImage: "record.circle")
                                }

                                Button("Clear All Shortcuts") {
                                    store.replaceShortcuts(in: profile, with: [])
                                }
                                .disabled(profile.shortcuts.isEmpty)
                            } label: {
                                Label("More", systemImage: "ellipsis.circle")
                            }
                        }
                    }

                    if store.activeProfileId != profile.id {
                        ToolbarItem {
                            Button("Make Active") {
                                store.switchTo(profile)
                            }
                        }
                    }

                    ToolbarItem {
                        Menu {
                            Button("Rename…") { rename(profile) }
                            Divider()
                            Button("Delete Profile", role: .destructive) {
                                store.deleteProfile(profile)
                            }
                        } label: {
                            Label("Profile Actions", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingAddShortcutSheet) {
                    AddShortcutSheet(
                        store: store,
                        profile: profile,
                        isPresented: $showingAddShortcutSheet
                    )
                }
                .sheet(isPresented: $showingRecorder) {
                    ShortcutRecorderView { newShortcut in
                        showingRecorder = false
                        if let newShortcut = newShortcut {
                            store.addShortcut(newShortcut, to: profile)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Profile",
                    systemImage: "sidebar.left",
                    description: Text("Choose a profile from the sidebar to manage its blocked shortcuts.")
                )
            }
        }
        .onAppear {
            store.refreshPermissions(force: true)
            if selectedProfileID == nil {
                selectedProfileID = store.profiles.first?.id
            }
        }
        .sheet(isPresented: $showingAddProfileSheet) {
            AddProfileSheet(
                name: $newProfileName,
                blockingMode: $newProfileBlockingMode,
                onCancel: { showingAddProfileSheet = false },
                onCreate: {
                    let trimmed = newProfileName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let created = store.addProfile(name: trimmed, blockingMode: newProfileBlockingMode)
                    selectedProfileID = created.id
                    showingAddProfileSheet = false
                    newProfileName = ""
                    newProfileBlockingMode = .selectedOnly
                }
            )
        }
    }

    // MARK: - Edit Profile Sections

    @ViewBuilder
    private func profileSummarySection(_ profile: Profile) -> some View {
        Section {
            HStack(spacing: 16) {
                profileIcon(for: profile)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(profileIconGradient(for: profile))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.title2.weight(.semibold))

                    Text(profileSummarySubtitle(profile))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            if store.activeProfileId == profile.id {
                LabeledContent("Status") {
                    Label("Active Profile", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }

    @ViewBuilder
    private func blockingModeSection(_ profile: Profile) -> some View {
        Section {
            Picker("Blocking Mode", selection: Binding(
                get: { profile.blockingMode },
                set: { store.setBlockingMode(profile, $0) }
            )) {
                Text("Selected shortcuts only").tag(BlockingChoice.selectedOnly)
                Text("All shortcuts except…").tag(BlockingChoice.allExcept)
                Text("All shortcuts").tag(BlockingChoice.all)
            }
            .pickerStyle(.radioGroup)
        } header: {
            Text("Blocking Behavior")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                switch profile.blockingMode {
                case .all:
                    Text("All keys using ⌘, ⌥, or ⌃ will be blocked, plus F1–F12. Normal typing still works.")
                case .allExcept:
                    Text("All keys using ⌘, ⌥, or ⌃ and F1–F12 will be blocked, except the shortcuts you allow below.")
                case .selectedOnly:
                    Text("Only the shortcuts in your blocked list will be intercepted while this profile is active.")
                }

                if !store.hasRequiredPermissions {
                    Text(AppPermissions.permissionsRequiredMessage)
                } else if !store.canBlockShortcuts {
                    Text(AppPermissions.restartAfterGrantingHint)
                }
            }
        }
    }

    private var allShortcutsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("All Shortcuts Blocked", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Text("This profile blocks every modifier-based shortcut (Command, Option, Control) and all function keys system-wide.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Coverage")
        } footer: {
            Text("Switch to “All shortcuts except…” or “Selected shortcuts only” for more control.")
        }
    }

    private var allExceptSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Block All Except Allowed", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Text("Every modifier shortcut and function key is blocked unless you add it to the allowed list below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Coverage")
        }
    }

    @ViewBuilder
    private func shortcutsListSection(_ profile: Profile) -> some View {
        let isExceptMode = profile.blockingMode == .allExcept

        Section {
            if profile.shortcuts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isExceptMode ? "No allowed shortcuts yet" : "No shortcuts blocked yet")
                        .foregroundStyle(.secondary)
                    Button {
                        showingAddShortcutSheet = true
                    } label: {
                        Label("Add Shortcut…", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                ForEach(profile.shortcuts) { shortcut in
                    HStack(spacing: 12) {
                        if let entry = PredefinedShortcuts.catalogEntry(for: shortcut) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                Text(entry.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Custom Shortcut")
                                Text("Recorded manually")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer(minLength: 12)

                        shortcutBadge(shortcut.displayString)

                        Button(role: .destructive) {
                            store.removeShortcut(shortcut, from: profile)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .help(isExceptMode ? "Remove from allowed list" : "Remove shortcut")
                    }
                }
            }
        } header: {
            HStack {
                Text(isExceptMode ? "Allowed Shortcuts" : "Blocked Shortcuts")
                Spacer()
                if !profile.shortcuts.isEmpty {
                    Button {
                        showingAddShortcutSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
                }
            }
        } footer: {
            if profile.shortcuts.isEmpty {
                if isExceptMode {
                    Text("With an empty allowed list, this profile behaves like “All shortcuts”. Add exceptions for shortcuts that should still work.")
                } else {
                    Text("Use Add Shortcut to browse common shortcuts, import your macOS system hotkeys, or record a custom combination.")
                }
            } else if isExceptMode {
                Text("\(profile.shortcuts.count) allowed shortcut\(profile.shortcuts.count == 1 ? "" : "s"); everything else is blocked.")
            } else {
                Text("\(profile.shortcuts.count) shortcut\(profile.shortcuts.count == 1 ? "" : "s") blocked in this profile.")
            }
        }
    }

    // MARK: - Helpers

    private func profileSubtitle(_ profile: Profile) -> String {
        switch profile.blockingMode {
        case .all:
            return "All shortcuts"
        case .allExcept:
            let count = profile.shortcuts.count
            return count == 0 ? "All except none" : "All except \(count)"
        case .selectedOnly:
            let count = profile.shortcuts.count
            return count == 1 ? "1 shortcut" : "\(count) shortcuts"
        }
    }

    private func profileSummarySubtitle(_ profile: Profile) -> String {
        switch profile.blockingMode {
        case .all:
            return "Blocks all modifier and function-key shortcuts"
        case .allExcept:
            let count = profile.shortcuts.count
            if count == 0 {
                return "Blocks all modifier and function-key shortcuts"
            }
            return "Blocks all except \(count) allowed shortcut\(count == 1 ? "" : "s")"
        case .selectedOnly:
            let count = profile.shortcuts.count
            return count == 1 ? "1 blocked shortcut" : "\(count) blocked shortcuts"
        }
    }

    private func profileIcon(for profile: Profile) -> Image {
        switch profile.blockingMode {
        case .all, .allExcept:
            return Image(systemName: "shield.lefthalf.filled")
        case .selectedOnly:
            return Image(systemName: "keyboard.badge.ellipsis")
        }
    }

    private func profileIconGradient(for profile: Profile) -> LinearGradient {
        switch profile.blockingMode {
        case .all, .allExcept:
            return LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .selectedOnly:
            return LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func shortcutBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private func rename(_ profile: Profile) {
        // Simple approach: use alert with new name
        let alert = NSAlert()
        alert.messageText = "Rename Profile"
        alert.informativeText = "Enter a new name for “\(profile.name)”"

        let textField = NSTextField(string: profile.name)
        textField.placeholderString = "Profile name"
        alert.accessoryView = textField

        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !newName.isEmpty {
                store.renameProfile(profile, to: newName)
            }
        }
    }

}

private struct AddProfileSheet: View {
    @Binding var name: String
    @Binding var blockingMode: ProfileBlockingMode
    var onCancel: () -> Void
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Profile name", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("Blocking Mode", selection: $blockingMode) {
                        Text("Selected shortcuts only").tag(ProfileBlockingMode.selectedOnly)
                        Text("All shortcuts except…").tag(ProfileBlockingMode.allExcept)
                        Text("All shortcuts").tag(ProfileBlockingMode.all)
                    }
                    .pickerStyle(.radioGroup)
                } header: {
                    Text("Blocking Behavior")
                } footer: {
                    switch blockingMode {
                    case .all:
                        Text("Everything using ⌘, ⌥, ⌃, or function keys will be blocked.")
                    case .allExcept:
                        Text("Block almost everything, then pick shortcuts that should still work.")
                    case .selectedOnly:
                        Text("You will choose exactly which shortcuts to disable.")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: onCreate)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 440)
        .padding(.top, 8)
    }
}
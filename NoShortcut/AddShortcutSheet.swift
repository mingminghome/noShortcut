import SwiftUI

struct AddShortcutSheet: View {
    @ObservedObject var store: ProfileStore
    let profile: Profile
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var catalogItems: [CatalogShortcut] = []
    @State private var showingRecorder = false

    private var currentProfile: Profile {
        store.profiles.first { $0.id == profile.id } ?? profile
    }

    private var filteredItems: [CatalogShortcut] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return catalogItems }
        return catalogItems.filter {
            $0.name.lowercased().contains(query) ||
            $0.category.lowercased().contains(query) ||
            $0.shortcut.displayString.lowercased().contains(query)
        }
    }

    private var groupedItems: [(String, [CatalogShortcut])] {
        let grouped = Dictionary(grouping: filteredItems, by: \.category)
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Shortcut")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search shortcuts…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if filteredItems.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedItems, id: \.0) { category, items in
                        Section(category) {
                            ForEach(items) { item in
                                catalogRow(item)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    refreshCatalog()
                } label: {
                    Label("Refresh System Hotkeys", systemImage: "arrow.clockwise")
                }

                Spacer()

                Button {
                    showingRecorder = true
                } label: {
                    Label("Record Custom…", systemImage: "record.circle")
                }
            }
            .padding(16)
        }
        .frame(width: 520, height: 560)
        .onAppear { refreshCatalog() }
        .sheet(isPresented: $showingRecorder) {
            ShortcutRecorderView { newShortcut in
                showingRecorder = false
                if let newShortcut {
                    store.addShortcut(newShortcut, to: currentProfile)
                }
            }
        }
    }

    @ViewBuilder
    private func catalogRow(_ item: CatalogShortcut) -> some View {
        let isAdded = ShortcutCatalog.contains(item, in: currentProfile)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                if item.isEnabledInSystem == false {
                    Text("Disabled in System Settings")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 8)

            Text(item.shortcut.displayString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Button {
                toggle(item)
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isAdded ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(isAdded ? "Remove from profile" : "Add to profile")
        }
        .padding(.vertical, 2)
    }

    private func refreshCatalog() {
        catalogItems = ShortcutCatalog.allItems(refreshSystem: true)
    }

    private func toggle(_ item: CatalogShortcut) {
        if ShortcutCatalog.contains(item, in: currentProfile) {
            store.removeShortcut(item.shortcut, from: currentProfile)
        } else {
            store.addShortcut(item.shortcut, to: currentProfile)
        }
    }

}
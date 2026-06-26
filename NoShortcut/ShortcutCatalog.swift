import Foundation

/// A blockable shortcut entry shown in the catalog picker and blocked-shortcuts list.
struct CatalogShortcut: Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let shortcut: Shortcut
    /// `nil` for common shortcuts; `true`/`false` for entries loaded from the system plist.
    let isEnabledInSystem: Bool?

    init(
        id: String,
        name: String,
        category: String,
        shortcut: Shortcut,
        isEnabledInSystem: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.shortcut = shortcut
        self.isEnabledInSystem = isEnabledInSystem
    }

    static func == (lhs: CatalogShortcut, rhs: CatalogShortcut) -> Bool {
        lhs.id == rhs.id
    }
}

enum ShortcutCatalog {
    private static var cachedSystemHotkeys: [CatalogShortcut] = []

    /// All picker items: common shortcuts plus live system hotkeys (deduplicated by key combo).
    static func allItems(refreshSystem: Bool = false) -> [CatalogShortcut] {
        if refreshSystem || cachedSystemHotkeys.isEmpty {
            cachedSystemHotkeys = SymbolicHotkeys.loadCatalogItems()
        }
        return deduplicated(PredefinedShortcuts.catalogItems + cachedSystemHotkeys)
    }

    /// Look up the best label for a shortcut already in a profile.
    static func lookup(for shortcut: Shortcut) -> CatalogShortcut? {
        let key = comboKey(shortcut)
        return allItems().first { comboKey($0.shortcut) == key }
    }

    static func contains(_ item: CatalogShortcut, in profile: Profile) -> Bool {
        profile.shortcuts.contains {
            $0.matches(keyCode: item.shortcut.keyCode, modifiers: item.shortcut.modifiers)
        }
    }

    // MARK: - Deduplication

    /// When a system hotkey shares the same key combo as a common shortcut, keep the system entry
    /// (it reflects the user's live binding) and drop the static duplicate.
    private static func deduplicated(_ items: [CatalogShortcut]) -> [CatalogShortcut] {
        var seen = Set<String>()
        var result: [CatalogShortcut] = []

        // System hotkeys first so they win over static entries with the same combo.
        let ordered = items.sorted { lhs, rhs in
            let lhsIsSystem = lhs.id.hasPrefix("sys-")
            let rhsIsSystem = rhs.id.hasPrefix("sys-")
            if lhsIsSystem != rhsIsSystem { return lhsIsSystem }
            if lhs.category != rhs.category { return lhs.category < rhs.category }
            return lhs.name < rhs.name
        }

        for item in ordered {
            let key = comboKey(item.shortcut)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(item)
        }

        return result
    }

    private static func comboKey(_ shortcut: Shortcut) -> String {
        "\(shortcut.keyCode)-\(shortcut.modifiers)"
    }
}
import Foundation
import AppKit

// MARK: - Shortcut

struct Shortcut: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    /// Raw value of NSEvent.ModifierFlags (device independent)
    var modifiers: Int
    var keyCode: UInt16
    /// Precomputed nice display string (e.g. "⌘Q", "⌘⇧Tab")
    var displayString: String

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(modifiers))
    }
}

// MARK: - Profile

enum ProfileBlockingMode: String, Codable, CaseIterable {
    /// Block only shortcuts in the profile list.
    case selectedOnly
    /// Block every ⌘/⌥/⌃ shortcut and F1–F12.
    case all
    /// Block every ⌘/⌥/⌃ shortcut and F1–F12, except those in the profile list.
    case allExcept
}

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    /// Blocklist in `.selectedOnly`, allowlist in `.allExcept`, ignored in `.all`.
    var shortcuts: [Shortcut]
    var blockingMode: ProfileBlockingMode

    static func == (lhs: Profile, rhs: Profile) -> Bool {
        lhs.id == rhs.id
    }

    var usesShortcutList: Bool {
        blockingMode == .selectedOnly || blockingMode == .allExcept
    }

    // Custom Codable so old saved profiles without `blockingMode` still load
    private enum CodingKeys: String, CodingKey {
        case id, name, shortcuts, blockingMode, blocksAllShortcuts
    }

    init(
        id: UUID,
        name: String,
        shortcuts: [Shortcut],
        blockingMode: ProfileBlockingMode = .selectedOnly
    ) {
        self.id = id
        self.name = name
        self.shortcuts = shortcuts
        self.blockingMode = blockingMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shortcuts = try container.decode([Shortcut].self, forKey: .shortcuts)

        if let mode = try container.decodeIfPresent(ProfileBlockingMode.self, forKey: .blockingMode) {
            blockingMode = mode
        } else {
            let blocksAll = try container.decodeIfPresent(Bool.self, forKey: .blocksAllShortcuts) ?? false
            blockingMode = blocksAll ? .all : .selectedOnly
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(shortcuts, forKey: .shortcuts)
        try container.encode(blockingMode, forKey: .blockingMode)
    }
}

// MARK: - Predefined / Common Shortcuts

/// A ready-to-use shortcut suggestion.
/// Users can toggle these on/off in a profile instead of having to record them manually.
struct PredefinedShortcut: Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let shortcut: Shortcut
}

enum PredefinedShortcuts {

    static let all: [PredefinedShortcut] = [
        // App Switching
        PredefinedShortcut(id: "cmd-tab",
                           name: "Switch Applications",
                           category: "App Switching",
                           shortcut: make(.command, 48, "⌘Tab")),
        PredefinedShortcut(id: "cmd-shift-tab",
                           name: "Switch Applications (Reverse)",
                           category: "App Switching",
                           shortcut: make([.command, .shift], 48, "⌘⇧Tab")),

        // Editing
        PredefinedShortcut(id: "cmd-z",
                           name: "Undo",
                           category: "Editing",
                           shortcut: make(.command, 6, "⌘Z")),
        PredefinedShortcut(id: "cmd-shift-z",
                           name: "Redo",
                           category: "Editing",
                           shortcut: make([.command, .shift], 6, "⌘⇧Z")),
        PredefinedShortcut(id: "cmd-x",
                           name: "Cut",
                           category: "Editing",
                           shortcut: make(.command, 7, "⌘X")),
        PredefinedShortcut(id: "cmd-c",
                           name: "Copy",
                           category: "Editing",
                           shortcut: make(.command, 8, "⌘C")),
        PredefinedShortcut(id: "cmd-v",
                           name: "Paste",
                           category: "Editing",
                           shortcut: make(.command, 9, "⌘V")),
        PredefinedShortcut(id: "cmd-a",
                           name: "Select All",
                           category: "Editing",
                           shortcut: make(.command, 0, "⌘A")),

        // File
        PredefinedShortcut(id: "cmd-n",
                           name: "New",
                           category: "File",
                           shortcut: make(.command, 45, "⌘N")),
        PredefinedShortcut(id: "cmd-shift-n",
                           name: "New Folder / Window",
                           category: "File",
                           shortcut: make([.command, .shift], 45, "⌘⇧N")),
        PredefinedShortcut(id: "cmd-o",
                           name: "Open",
                           category: "File",
                           shortcut: make(.command, 31, "⌘O")),
        PredefinedShortcut(id: "cmd-s",
                           name: "Save",
                           category: "File",
                           shortcut: make(.command, 1, "⌘S")),
        PredefinedShortcut(id: "cmd-shift-s",
                           name: "Save As",
                           category: "File",
                           shortcut: make([.command, .shift], 1, "⌘⇧S")),
        PredefinedShortcut(id: "cmd-p",
                           name: "Print",
                           category: "File",
                           shortcut: make(.command, 35, "⌘P")),

        // Tabs & Navigation
        PredefinedShortcut(id: "cmd-t",
                           name: "New Tab",
                           category: "Tabs & Navigation",
                           shortcut: make(.command, 17, "⌘T")),
        PredefinedShortcut(id: "cmd-shift-t",
                           name: "Reopen Closed Tab",
                           category: "Tabs & Navigation",
                           shortcut: make([.command, .shift], 17, "⌘⇧T")),
        PredefinedShortcut(id: "cmd-r",
                           name: "Reload Page",
                           category: "Tabs & Navigation",
                           shortcut: make(.command, 15, "⌘R")),
        PredefinedShortcut(id: "cmd-l",
                           name: "Focus Address Bar",
                           category: "Tabs & Navigation",
                           shortcut: make(.command, 37, "⌘L")),
        PredefinedShortcut(id: "cmd-f",
                           name: "Find",
                           category: "Tabs & Navigation",
                           shortcut: make(.command, 3, "⌘F")),

        // Spotlight & Search
        PredefinedShortcut(id: "cmd-space",
                           name: "Spotlight Search",
                           category: "Search & Launchers",
                           shortcut: make(.command, 49, "⌘Space")),
        PredefinedShortcut(id: "alt-space",
                           name: "Launcher / Input Switcher (Alt+Space)",
                           category: "Search & Launchers",
                           shortcut: make(.option, 49, "⌥Space")),
        PredefinedShortcut(id: "ctrl-space",
                           name: "Input Method Switcher (Ctrl+Space)",
                           category: "Search & Launchers",
                           shortcut: make(.control, 49, "⌃Space")),

        // Window Management
        PredefinedShortcut(id: "cmd-grave",
                           name: "Cycle Windows (Same App)",
                           category: "Window Management",
                           shortcut: make(.command, 50, "⌘`")),
        PredefinedShortcut(id: "cmd-m",
                           name: "Minimize Window",
                           category: "Window Management",
                           shortcut: make(.command, 46, "⌘M")),
        PredefinedShortcut(id: "cmd-opt-m",
                           name: "Minimize All Windows",
                           category: "Window Management",
                           shortcut: make([.command, .option], 46, "⌘⌥M")),
        PredefinedShortcut(id: "ctrl-cmd-f",
                           name: "Toggle Full Screen",
                           category: "Window Management",
                           shortcut: make([.control, .command], 3, "⌃⌘F")),

        // Quitting & Closing
        PredefinedShortcut(id: "cmd-q",
                           name: "Quit Application",
                           category: "Quitting & Closing",
                           shortcut: make(.command, 12, "⌘Q")),
        PredefinedShortcut(id: "cmd-shift-q",
                           name: "Quit Application (with confirmation)",
                           category: "Quitting & Closing",
                           shortcut: make([.command, .shift], 12, "⌘⇧Q")),
        PredefinedShortcut(id: "cmd-w",
                           name: "Close Window",
                           category: "Quitting & Closing",
                           shortcut: make(.command, 13, "⌘W")),
        PredefinedShortcut(id: "cmd-shift-w",
                           name: "Close All Windows",
                           category: "Quitting & Closing",
                           shortcut: make([.command, .shift], 13, "⌘⇧W")),
        PredefinedShortcut(id: "cmd-h",
                           name: "Hide Application",
                           category: "Quitting & Closing",
                           shortcut: make(.command, 4, "⌘H")),
        PredefinedShortcut(id: "cmd-opt-h",
                           name: "Hide Other Applications",
                           category: "Quitting & Closing",
                           shortcut: make([.command, .option], 4, "⌘⌥H")),
        PredefinedShortcut(id: "cmd-opt-w",
                           name: "Close All (App)",
                           category: "Quitting & Closing",
                           shortcut: make([.command, .option], 13, "⌘⌥W")),

        // System
        PredefinedShortcut(id: "cmd-comma",
                           name: "Preferences / Settings",
                           category: "System",
                           shortcut: make(.command, 43, "⌘,")),
        PredefinedShortcut(id: "cmd-opt-esc",
                           name: "Force Quit Applications",
                           category: "System",
                           shortcut: make([.command, .option], 53, "⌘⌥Esc")),
        PredefinedShortcut(id: "cmd-opt-d",
                           name: "Toggle Dock Autohide",
                           category: "System",
                           shortcut: make([.command, .option], 2, "⌘⌥D")),

        // Screenshots
        PredefinedShortcut(id: "cmd-shift-3",
                           name: "Screenshot — Full Screen",
                           category: "Screenshots",
                           shortcut: make([.command, .shift], 20, "⌘⇧3")),
        PredefinedShortcut(id: "cmd-shift-4",
                           name: "Screenshot — Selection",
                           category: "Screenshots",
                           shortcut: make([.command, .shift], 21, "⌘⇧4")),
        PredefinedShortcut(id: "cmd-shift-5",
                           name: "Screenshot & Recording Options",
                           category: "Screenshots",
                           shortcut: make([.command, .shift], 23, "⌘⇧5")),

        // Function Keys
        PredefinedShortcut(id: "f1",
                           name: "F1",
                           category: "Function Keys",
                           shortcut: make([], 122, "F1")),
        PredefinedShortcut(id: "f2",
                           name: "F2",
                           category: "Function Keys",
                           shortcut: make([], 120, "F2")),
        PredefinedShortcut(id: "f3",
                           name: "Mission Control",
                           category: "Function Keys",
                           shortcut: make([], 99, "F3")),
        PredefinedShortcut(id: "f4",
                           name: "Launchpad / Spotlight (varies)",
                           category: "Function Keys",
                           shortcut: make([], 118, "F4")),
        PredefinedShortcut(id: "f5",
                           name: "F5 (often Dictation / Focus)",
                           category: "Function Keys",
                           shortcut: make([], 96, "F5")),
        PredefinedShortcut(id: "f6",
                           name: "F6",
                           category: "Function Keys",
                           shortcut: make([], 97, "F6")),
        PredefinedShortcut(id: "f7",
                           name: "F7",
                           category: "Function Keys",
                           shortcut: make([], 98, "F7")),
        PredefinedShortcut(id: "f8",
                           name: "F8",
                           category: "Function Keys",
                           shortcut: make([], 100, "F8")),
        PredefinedShortcut(id: "f9",
                           name: "F9",
                           category: "Function Keys",
                           shortcut: make([], 101, "F9")),
        PredefinedShortcut(id: "f10",
                           name: "F10",
                           category: "Function Keys",
                           shortcut: make([], 109, "F10")),
        PredefinedShortcut(id: "f11",
                           name: "F11 (Show Desktop)",
                           category: "Function Keys",
                           shortcut: make([], 103, "F11")),
        PredefinedShortcut(id: "f12",
                           name: "F12 (often Dashboard / Siri)",
                           category: "Function Keys",
                           shortcut: make([], 111, "F12")),
    ]

    static var catalogItems: [CatalogShortcut] {
        all.map {
            CatalogShortcut(id: $0.id, name: $0.name, category: $0.category, shortcut: $0.shortcut)
        }
    }

    private static func make(_ modifiers: NSEvent.ModifierFlags, _ keyCode: UInt16, _ display: String) -> Shortcut {
        Shortcut(id: UUID(), modifiers: Int(modifiers.rawValue), keyCode: keyCode, displayString: display)
    }

    private static func make(_ modifiers: [NSEvent.ModifierFlags], _ keyCode: UInt16, _ display: String) -> Shortcut {
        let combined = modifiers.reduce(into: NSEvent.ModifierFlags()) { $0.insert($1) }
        return make(combined, keyCode, display)
    }

    /// Returns the predefined entry that matches this shortcut (if any)
    static func predefined(for shortcut: Shortcut) -> PredefinedShortcut? {
        all.first { $0.shortcut.keyCode == shortcut.keyCode &&
                    $0.shortcut.modifiers == shortcut.modifiers }
    }

    /// Best available label for a shortcut (common catalog or live system hotkey).
    static func catalogEntry(for shortcut: Shortcut) -> CatalogShortcut? {
        ShortcutCatalog.lookup(for: shortcut)
    }

    /// Check whether a profile currently contains this predefined shortcut
    static func isEnabled(_ predefined: PredefinedShortcut, in profile: Profile) -> Bool {
        profile.shortcuts.contains { $0.keyCode == predefined.shortcut.keyCode &&
                                     $0.modifiers == predefined.shortcut.modifiers }
    }
}

// Convenience extension for matching
extension Shortcut {
    func matches(keyCode: UInt16, modifiers: Int) -> Bool {
        return self.keyCode == keyCode && self.modifiers == modifiers
    }

    var matchesAnyPredefined: Bool {
        PredefinedShortcuts.all.contains { $0.shortcut.keyCode == self.keyCode && $0.shortcut.modifiers == self.modifiers }
    }
}

// MARK: - Container for persistence

struct AppData: Codable {
    var profiles: [Profile]
    var activeProfileId: UUID?
    var isEnabled: Bool
}

// MARK: - Default profiles factory

enum DefaultProfiles {
    static let shortcutIDs: Set<String> = [
        "alt-space", "ctrl-space"
    ]

    static func makeDefaults() -> [Profile] {
        let shortcuts = PredefinedShortcuts.all
            .filter { shortcutIDs.contains($0.id) }
            .map(\.shortcut)
        return [
            Profile(id: UUID(), name: "Default", shortcuts: shortcuts, blockingMode: .selectedOnly)
        ]
    }
}

// MARK: - Key code helpers (display + recording)

enum KeyCodeMapper {
    /// Basic virtual key code → human string. Extend as needed.
    private static let keyMap: [UInt16: String] = [
        // Letters
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y",
        17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
        45: "N", 46: "M",
        // Numbers
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        // Symbols
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\",
        43: ",", 44: "/", 47: ".", 50: "`",
        // Special
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        117: "ForwardDelete", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
        96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
        // Arrows
        126: "↑", 125: "↓", 123: "←", 124: "→",
        // Others
        115: "Home", 119: "End", 116: "PageUp", 121: "PageDown"
    ]

    static func displayString(for keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""

        if modifiers.contains(.command) { result += "⌘" }
        if modifiers.contains(.option)  { result += "⌥" }
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.shift)   { result += "⇧" }

        if let char = keyMap[keyCode] {
            result += char
        } else {
            result += "Key\(keyCode)"
        }
        return result
    }

    /// Try to produce a nicer char when recording (uses the charactersIgnoringModifiers when possible)
    static func displayString(from event: NSEvent) -> String {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var result = ""

        if mods.contains(.command) { result += "⌘" }
        if mods.contains(.option)  { result += "⌥" }
        if mods.contains(.control) { result += "⌃" }
        if mods.contains(.shift)   { result += "⇧" }

        // Prefer charactersIgnoringModifiers for display
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            let upper = chars.uppercased()
            // For space / special we keep the map
            if upper == " " {
                result += "Space"
            } else {
                result += upper
            }
        } else if let mapped = keyMap[event.keyCode] {
            result += mapped
        } else {
            result += "Key\(event.keyCode)"
        }
        return result
    }
}
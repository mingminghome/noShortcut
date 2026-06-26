import Foundation
import AppKit

// MARK: - Symbolic hotkey definitions (com.apple.symbolichotkeys.plist)

struct SymbolicHotkeyDefinition {
    let id: Int
    let name: String
    let category: String
    /// [ascii/keyChar, virtualKeyCode, modifierMask] — 65535 means "use virtual key only"
    let defaultParameters: [Int]
}

enum SymbolicHotkeys {
    static let definitions: [SymbolicHotkeyDefinition] = [
        SymbolicHotkeyDefinition(id: 7, name: "Move Focus to Menu Bar", category: "System Hotkeys",
                                 defaultParameters: [65535, 120, 8650752]),
        SymbolicHotkeyDefinition(id: 8, name: "Move Focus to Dock", category: "System Hotkeys",
                                 defaultParameters: [65535, 99, 8650752]),
        SymbolicHotkeyDefinition(id: 9, name: "Move Focus to Active Window", category: "System Hotkeys",
                                 defaultParameters: [65535, 118, 8650752]),
        SymbolicHotkeyDefinition(id: 10, name: "Move Focus to Window Toolbar", category: "System Hotkeys",
                                 defaultParameters: [65535, 96, 8650752]),
        SymbolicHotkeyDefinition(id: 11, name: "Move Focus to Floating Window", category: "System Hotkeys",
                                 defaultParameters: [65535, 97, 8650752]),
        SymbolicHotkeyDefinition(id: 12, name: "Turn Keyboard Access On/Off", category: "System Hotkeys",
                                 defaultParameters: [65535, 122, 8650752]),
        SymbolicHotkeyDefinition(id: 13, name: "Change Tab Focus Navigation", category: "System Hotkeys",
                                 defaultParameters: [65535, 98, 8650752]),
        SymbolicHotkeyDefinition(id: 27, name: "Move Focus to Next Window", category: "System Hotkeys",
                                 defaultParameters: [96, 50, 1048576]),
        SymbolicHotkeyDefinition(id: 28, name: "Save Screenshot to File", category: "System Hotkeys",
                                 defaultParameters: [51, 20, 1179648]),
        SymbolicHotkeyDefinition(id: 29, name: "Copy Screenshot to Clipboard", category: "System Hotkeys",
                                 defaultParameters: [51, 20, 1441792]),
        SymbolicHotkeyDefinition(id: 30, name: "Save Selection Screenshot to File", category: "System Hotkeys",
                                 defaultParameters: [52, 21, 1179648]),
        SymbolicHotkeyDefinition(id: 31, name: "Copy Selection Screenshot to Clipboard", category: "System Hotkeys",
                                 defaultParameters: [52, 21, 1441792]),
        SymbolicHotkeyDefinition(id: 32, name: "Mission Control", category: "System Hotkeys",
                                 defaultParameters: [65535, 126, 8650752]),
        SymbolicHotkeyDefinition(id: 34, name: "Mission Control (Fn Key)", category: "System Hotkeys",
                                 defaultParameters: [65535, 126, 8781824]),
        SymbolicHotkeyDefinition(id: 35, name: "Application Windows", category: "System Hotkeys",
                                 defaultParameters: [65535, 125, 8781824]),
        SymbolicHotkeyDefinition(id: 36, name: "Show Desktop", category: "System Hotkeys",
                                 defaultParameters: [65535, 103, 8388608]),
        SymbolicHotkeyDefinition(id: 37, name: "Show Desktop (Fn Key)", category: "System Hotkeys",
                                 defaultParameters: [65535, 103, 8519680]),
        SymbolicHotkeyDefinition(id: 52, name: "Turn Dock Hiding On/Off", category: "System Hotkeys",
                                 defaultParameters: [100, 2, 1572864]),
        SymbolicHotkeyDefinition(id: 57, name: "Move Focus to Status Menus", category: "System Hotkeys",
                                 defaultParameters: [65535, 100, 8650752]),
        SymbolicHotkeyDefinition(id: 60, name: "Select Previous Input Source", category: "System Hotkeys",
                                 defaultParameters: [32, 49, 262144]),
        SymbolicHotkeyDefinition(id: 61, name: "Select Next Input Source", category: "System Hotkeys",
                                 defaultParameters: [32, 49, 786432]),
        SymbolicHotkeyDefinition(id: 64, name: "Spotlight Search", category: "System Hotkeys",
                                 defaultParameters: [32, 49, 1048576]),
        SymbolicHotkeyDefinition(id: 79, name: "Move Left a Space", category: "System Hotkeys",
                                 defaultParameters: [65535, 123, 8650752]),
        SymbolicHotkeyDefinition(id: 80, name: "Move Left a Space (Fn Key)", category: "System Hotkeys",
                                 defaultParameters: [65535, 123, 8781824]),
        SymbolicHotkeyDefinition(id: 81, name: "Move Right a Space", category: "System Hotkeys",
                                 defaultParameters: [65535, 124, 8650752]),
        SymbolicHotkeyDefinition(id: 82, name: "Move Right a Space (Fn Key)", category: "System Hotkeys",
                                 defaultParameters: [65535, 124, 8781824]),
        SymbolicHotkeyDefinition(id: 118, name: "Switch to Desktop 1", category: "System Hotkeys",
                                 defaultParameters: [65535, 18, 262144]),
        SymbolicHotkeyDefinition(id: 119, name: "Switch to Desktop 2", category: "System Hotkeys",
                                 defaultParameters: [65535, 19, 262144]),
        SymbolicHotkeyDefinition(id: 120, name: "Switch to Desktop 3", category: "System Hotkeys",
                                 defaultParameters: [65535, 20, 262144]),
        SymbolicHotkeyDefinition(id: 184, name: "Screenshot & Recording Options", category: "System Hotkeys",
                                 defaultParameters: [53, 23, 1179648]),
    ]

    private static let plistURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")
    }()

    /// Load system hotkeys from the user's plist, falling back to Apple defaults.
    static func loadCatalogItems() -> [CatalogShortcut] {
        let plist = NSDictionary(contentsOf: plistURL)
        let hotkeys = plist?["AppleSymbolicHotKeys"] as? [String: [String: Any]] ?? [:]

        return definitions.compactMap { definition in
            let entry = hotkeys["\(definition.id)"]
            let enabled = entry?["enabled"] as? Bool ?? true

            let parameters: [Int]
            if let value = entry?["value"] as? [String: Any],
               let params = value["parameters"] as? [Int],
               params.count >= 3,
               params[1] != 65535 {
                parameters = params
            } else {
                parameters = definition.defaultParameters
            }

            guard let shortcut = shortcut(from: parameters) else { return nil }

            var name = definition.name
            if !enabled {
                name += " (off in System Settings)"
            }

            return CatalogShortcut(
                id: "sys-\(definition.id)",
                name: name,
                category: definition.category,
                shortcut: shortcut,
                isEnabledInSystem: enabled
            )
        }
    }

    // MARK: - Parameter conversion

    private static func shortcut(from parameters: [Int]) -> Shortcut? {
        guard parameters.count >= 3 else { return nil }

        let keyCode = UInt16(parameters[1])
        guard keyCode != 65535 else { return nil }

        let modifiers = modifiers(fromSymbolicMask: parameters[2])
        let display = KeyCodeMapper.displayString(for: keyCode, modifiers: modifiers)

        return Shortcut(
            id: UUID(),
            modifiers: Int(modifiers.rawValue),
            keyCode: keyCode,
            displayString: display
        )
    }

    /// Symbolic hotkey modifier mask uses bits 17–20 (shift, control, option, command).
    private static func modifiers(fromSymbolicMask value: Int) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if value & 0x100000 != 0 { flags.insert(.command) }
        if value & 0x080000 != 0 { flags.insert(.option) }
        if value & 0x040000 != 0 { flags.insert(.control) }
        if value & 0x020000 != 0 { flags.insert(.shift) }
        return flags.intersection(.deviceIndependentFlagsMask)
    }
}
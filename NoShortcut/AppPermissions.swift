import AppKit
import ApplicationServices
import CoreGraphics

enum AppPermission: String, CaseIterable, Identifiable {
    case accessibility
    case inputMonitoring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        }
    }

    var isRequired: Bool { true }

    var settingsLabel: String {
        "Open \(title) Settings…"
    }

    var isGranted: Bool {
        switch self {
        case .inputMonitoring:
            return CGPreflightListenEventAccess()
        case .accessibility:
            return Self.isAccessibilityTrusted()
        }
    }

    func openSettings() {
        let urlString: String
        switch self {
        case .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private static func isAccessibilityTrusted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

enum AppPermissions {
    static let permissionsRequiredMessage =
        "Grant Accessibility and Input Monitoring in Privacy & Security to block keyboard shortcuts."

    static let restartAfterGrantingHint =
        "Quit and reopen NoShortcut after granting permission in System Settings."

    static var hasAllRequired: Bool {
        missingRequired.isEmpty
    }

    static var missingRequired: [AppPermission] {
        AppPermission.allCases.filter { $0.isRequired && !$0.isGranted }
    }

    /// Whether the app can actually install a global event tap right now.
    static func canBlockShortcuts(forceRefresh: Bool = false) -> Bool {
        hasAllRequired && EventTapProbe.canCreateEventTap(forceRefresh: forceRefresh)
    }

    static var isInputMonitoringGranted: Bool {
        AppPermission.inputMonitoring.isGranted
    }

    static var isAccessibilityGranted: Bool {
        AppPermission.accessibility.isGranted
    }
}
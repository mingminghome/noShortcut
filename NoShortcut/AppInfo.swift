import Foundation

enum AppInfo {
    static let name = "NoShortcut"
    static let developer = "MingMingHomeWork"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var versionString: String {
        "Version \(version) (\(build))"
    }
}
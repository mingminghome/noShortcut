import Foundation
import AppKit
import Combine

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var activeProfileId: UUID?
    @Published var isEnabled: Bool = false
    @Published private(set) var hasRequiredPermissions = AppPermissions.hasAllRequired
    @Published private(set) var missingRequiredPermissions = AppPermissions.missingRequired
    @Published private(set) var canBlockShortcuts = AppPermissions.canBlockShortcuts()

    private let disabler = ShortcutDisabler()
    private let fileURL: URL
    private var saveCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    var currentProfile: Profile? {
        guard let id = activeProfileId else { return nil }
        return profiles.first { $0.id == id }
    }

    var activeShortcuts: [Shortcut] {
        currentProfile?.shortcuts ?? []
    }

    var isBlockingAll: Bool {
        currentProfile?.blockingMode == .all
    }

    var isBlockingAllExcept: Bool {
        currentProfile?.blockingMode == .allExcept
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("NoShortcut", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("profiles.json")

        load()

        if profiles.isEmpty {
            profiles = DefaultProfiles.makeDefaults()
            activeProfileId = profiles.first?.id
            save()
        }

        // Auto-save on changes
        saveCancellable = Publishers.CombineLatest3($profiles, $activeProfileId, $isEnabled)
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.save()
            }

        // Keep the disabler in sync whenever relevant state changes
        Publishers.CombineLatest3($profiles, $activeProfileId, $isEnabled)
            .sink { [weak self] _, _, _ in
                self?.applyToDisabler()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshPermissions(force: true)
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                self?.refreshPermissions(force: true)
            }
            .store(in: &cancellables)

        Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if !self.hasRequiredPermissions || !self.canBlockShortcuts {
                    self.refreshPermissions(force: true)
                }
            }
            .store(in: &cancellables)

        refreshPermissions(force: true)

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.disabler.disable()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    func setEnabled(_ enabled: Bool) {
        guard hasRequiredPermissions else { return }

        if enabled {
            refreshPermissions(force: true)
            guard canBlockShortcuts else { return }
        }

        isEnabled = enabled
        applyToDisabler()
    }

    func refreshPermissions(force: Bool = false) {
        if force {
            EventTapProbe.invalidateCache()
        }

        missingRequiredPermissions = AppPermissions.missingRequired
        hasRequiredPermissions = AppPermissions.hasAllRequired
        canBlockShortcuts = AppPermissions.canBlockShortcuts(forceRefresh: force)

        if !hasRequiredPermissions && isEnabled {
            isEnabled = false
        }
    }

    func toggle() {
        isEnabled.toggle()
    }

    func switchTo(_ profile: Profile) {
        guard profiles.contains(where: { $0.id == profile.id }) else { return }
        activeProfileId = profile.id
        // applyToDisabler() is called via the publisher
    }

    func addProfile(name: String, blockingMode: ProfileBlockingMode = .selectedOnly) -> Profile {
        let new = Profile(id: UUID(), name: name, shortcuts: [], blockingMode: blockingMode)
        profiles.append(new)
        if activeProfileId == nil {
            activeProfileId = new.id
        }
        return new
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfileId == profile.id {
            activeProfileId = profiles.first?.id
        }
        if profiles.isEmpty {
            // Recreate a safe default
            let def = DefaultProfiles.makeDefaults().first!
            profiles = [def]
            activeProfileId = def.id
        }
    }

    func renameProfile(_ profile: Profile, to newName: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx].name = newName
    }

    func addShortcut(_ shortcut: Shortcut, to profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        // Avoid duplicates
        if !profiles[idx].shortcuts.contains(where: {
            $0.keyCode == shortcut.keyCode && $0.modifiers == shortcut.modifiers
        }) {
            profiles[idx].shortcuts.append(shortcut)
        }
    }

    func removeShortcut(_ shortcut: Shortcut, from profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx].shortcuts.removeAll {
            $0.id == shortcut.id ||
            $0.matches(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
        }
    }

    func replaceShortcuts(in profile: Profile, with newShortcuts: [Shortcut]) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx].shortcuts = newShortcuts
    }

    func setBlockingMode(_ profile: Profile, _ mode: ProfileBlockingMode) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx].blockingMode = mode
    }

    // MARK: - Predefined Shortcuts helpers

    func containsPredefined(_ predefined: PredefinedShortcut, in profile: Profile) -> Bool {
        PredefinedShortcuts.isEnabled(predefined, in: profile)
    }

    func addPredefined(_ predefined: PredefinedShortcut, to profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let target = predefined.shortcut
        if !profiles[idx].shortcuts.contains(where: { $0.matches(keyCode: target.keyCode, modifiers: target.modifiers) }) {
            profiles[idx].shortcuts.append(target)
        }
    }

    func removePredefined(_ predefined: PredefinedShortcut, from profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let target = predefined.shortcut
        profiles[idx].shortcuts.removeAll { $0.matches(keyCode: target.keyCode, modifiers: target.modifiers) }
    }

    func togglePredefined(_ predefined: PredefinedShortcut, in profile: Profile) {
        if containsPredefined(predefined, in: profile) {
            removePredefined(predefined, from: profile)
        } else {
            addPredefined(predefined, to: profile)
        }
    }

    /// Returns all predefined shortcuts that are currently active in the given profile
    func enabledPredefined(in profile: Profile) -> [PredefinedShortcut] {
        PredefinedShortcuts.all.filter { containsPredefined($0, in: profile) }
    }

    /// Returns only the custom (non-catalog) shortcuts in a profile
    func customShortcuts(in profile: Profile) -> [Shortcut] {
        profile.shortcuts.filter { ShortcutCatalog.lookup(for: $0) == nil }
    }

    // MARK: - Disabler sync

    private func applyToDisabler() {
        let profile = currentProfile
        let shortcuts = profile?.shortcuts ?? []
        let mode = profile?.blockingMode ?? .selectedOnly
        disabler.update(shortcuts: shortcuts, mode: mode, enabled: isEnabled)

        if isEnabled && !disabler.isTapInstalled {
            isEnabled = false
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode(AppData.self, from: data)
            self.profiles = decoded.profiles
            self.activeProfileId = decoded.activeProfileId
            self.isEnabled = decoded.isEnabled
        } catch {
            print("Failed to decode profiles: \(error)")
        }
    }

    private func save() {
        let data = AppData(
            profiles: profiles,
            activeProfileId: activeProfileId,
            isEnabled: isEnabled
        )
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save profiles: \(error)")
        }
    }

    // MARK: - Permission helper

    static func openInputMonitoringPreferences() {
        AppPermission.inputMonitoring.openSettings()
    }

    static func openAccessibilityPreferences() {
        AppPermission.accessibility.openSettings()
    }

    var hasActiveBlocking: Bool {
        guard isEnabled, let profile = currentProfile else { return false }
        switch profile.blockingMode {
        case .selectedOnly:
            return !profile.shortcuts.isEmpty
        case .all, .allExcept:
            return true
        }
    }

    var canEnableBlocking: Bool {
        guard let profile = currentProfile else { return false }
        switch profile.blockingMode {
        case .selectedOnly:
            return !profile.shortcuts.isEmpty
        case .all, .allExcept:
            return true
        }
    }

    var blockingStatusLabel: String {
        guard hasRequiredPermissions else {
            let names = missingRequiredPermissions.map(\.title).joined(separator: " & ")
            return "\(names) permission required"
        }

        let profileName = currentProfile?.name ?? "No profile"

        if isEnabled {
            switch currentProfile?.blockingMode {
            case .all:
                return "Blocking active · All shortcuts · \(profileName)"
            case .allExcept:
                let count = activeShortcuts.count
                if count == 0 {
                    return "Blocking active · All shortcuts · \(profileName)"
                }
                return "Blocking active · All except \(count) · \(profileName)"
            case .selectedOnly, .none:
                let count = activeShortcuts.count
                if count == 0 {
                    return "Blocking active · No shortcuts configured · \(profileName)"
                }
                return "Blocking active · \(count) blocked · \(profileName)"
            }
        }

        return "Blocking off · \(profileName)"
    }

    var menuBarStatusSummary: String {
        if !hasRequiredPermissions {
            let names = missingRequiredPermissions.map(\.title).joined(separator: ", ")
            return "\(names) not granted"
        }

        let profileName = currentProfile?.name ?? "No profile"

        if isEnabled {
            switch currentProfile?.blockingMode {
            case .all:
                return "Shortcuts disabled · All shortcuts blocked · \(profileName)"
            case .allExcept:
                let count = activeShortcuts.count
                if count == 0 {
                    return "Shortcuts disabled · All shortcuts blocked · \(profileName)"
                }
                return "Shortcuts disabled · All except \(count) allowed · \(profileName)"
            case .selectedOnly, .none:
                let count = activeShortcuts.count
                if count == 0 {
                    return "Shortcuts disabled · No shortcuts configured · \(profileName)"
                }
                return "Shortcuts disabled · \(count) blocked · \(profileName)"
            }
        }

        return "Shortcuts enabled · \(profileName)"
    }
}
import SwiftUI
import AppKit
import Combine

struct MenuBarView: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.openWindow) private var openWindow
    @State private var showingAbout = false

    var body: some View {
        Group {
            if showingAbout {
                aboutPanel
            } else {
                mainPanel
            }
        }
        .padding(16)
        .frame(width: 300)
        .animation(.easeInOut(duration: 0.18), value: showingAbout)
        .onAppear {
            store.refreshPermissions(force: true)
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            if !store.hasRequiredPermissions || !store.canBlockShortcuts {
                store.refreshPermissions(force: true)
            }
        }
    }

    // MARK: - Panels

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusCard
            blockingCard

            if !store.hasRequiredPermissions {
                requiredPermissionBanner
            }

            profileCard
            actionsCard
        }
    }

    private var aboutPanel: some View {
        AboutView(onClose: { showingAbout = false })
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            AppIconView(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppInfo.name)
                    .font(.headline)
                Text(AppInfo.versionString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var statusCard: some View {
        sectionCard {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var blockingCard: some View {
        sectionCard {
            Toggle(isOn: blockingBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block Shortcuts")
                        .font(.subheadline.weight(.medium))

                    Text(blockingToggleSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!store.hasRequiredPermissions || !store.canBlockShortcuts)
        }
    }

    private var requiredPermissionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Permissions Required")
                        .font(.subheadline.weight(.semibold))

                    Text(AppPermissions.permissionsRequiredMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(store.missingRequiredPermissions) { permission in
                HStack {
                    Label(permission.title, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)

                    Spacer()

                    Button("Open") {
                        permission.openSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Profile")

            sectionCard {
                if store.profiles.isEmpty {
                    Text("No profiles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 6) {
                        ForEach(store.profiles) { profile in
                            profileRow(profile)
                        }
                    }
                }
            }
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        let isActive = profile.id == store.activeProfileId

        return Button {
            store.switchTo(profile)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(profileRowSubtitle(profile))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isActive ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            MenuBarActionButton(
                title: "Manage Profiles",
                subtitle: "Edit shortcuts and profiles",
                systemImage: "square.and.pencil",
                style: .primary
            ) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "manage-profiles")
            }

            HStack(spacing: 10) {
                MenuBarActionButton(
                    title: "About",
                    systemImage: "info.circle",
                    style: .secondary
                ) {
                    showingAbout = true
                }

                MenuBarActionButton(
                    title: "Quit",
                    systemImage: "power",
                    style: .destructive
                ) {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }

    // MARK: - Helpers

    private var blockingBinding: Binding<Bool> {
        Binding(
            get: { store.isEnabled },
            set: { newValue in
                let canBlock = store.canEnableBlocking
                if newValue && !canBlock {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "manage-profiles")
                    store.setEnabled(newValue)
                } else {
                    store.setEnabled(newValue)
                }
            }
        )
    }

    private var statusColor: Color {
        if !store.hasRequiredPermissions { return .orange }
        return store.isEnabled ? .orange : .green
    }

    private var statusTitle: String {
        if !store.hasRequiredPermissions {
            return "Permission Required"
        }
        return store.isEnabled ? "Blocking Active" : "Blocking Off"
    }

    private var statusDetail: String {
        if !store.hasRequiredPermissions {
            let names = store.missingRequiredPermissions.map(\.title).joined(separator: " and ")
            return "Enable \(names) to use NoShortcut."
        }

        if !store.canBlockShortcuts {
            return AppPermissions.restartAfterGrantingHint
        }

        guard let profile = store.currentProfile else {
            return "No profile selected."
        }

        if store.isEnabled {
            switch profile.blockingMode {
            case .all:
                return "All shortcuts blocked · \(profile.name)"
            case .allExcept:
                let count = profile.shortcuts.count
                if count == 0 {
                    return "All shortcuts blocked · \(profile.name)"
                }
                return "All except \(count) allowed · \(profile.name)"
            case .selectedOnly:
                let count = profile.shortcuts.count
                if count == 0 {
                    return "No shortcuts configured · \(profile.name)"
                }
                return "\(count) shortcut\(count == 1 ? "" : "s") blocked · \(profile.name)"
            }
        }

        return "Shortcuts pass through · \(profile.name)"
    }

    private var blockingToggleSubtitle: String {
        if !store.hasRequiredPermissions {
            return "Unavailable until permissions are granted"
        }
        if !store.canBlockShortcuts {
            return "Restart NoShortcut after granting permissions"
        }
        if store.isEnabled {
            return "Shortcuts are currently blocked"
        }
        return "Allow macOS shortcuts normally"
    }

    private func profileRowSubtitle(_ profile: Profile) -> String {
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

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MenuBarActionButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    let title: String
    var subtitle: String?
    let systemImage: String
    let style: Style
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(subtitleColor)
                    }
                }

                Spacer(minLength: 0)

                if style == .primary {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(background)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .onHover { isHovered = $0 }
    }

    private var minHeight: CGFloat {
        subtitle == nil ? 44 : 52
    }

    private var verticalPadding: CGFloat {
        subtitle == nil ? 10 : 12
    }

    private var iconSize: CGFloat {
        style == .primary ? 15 : 14
    }

    private var foreground: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .primary
        case .destructive: return Color(red: 0.85, green: 0.22, blue: 0.22)
        }
    }

    private var subtitleColor: Color {
        style == .primary ? .white.opacity(0.78) : .secondary
    }

    private var background: some ShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(isHovered ? 1.0 : 0.92),
                        Color.accentColor.opacity(isHovered ? 0.82 : 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            return AnyShapeStyle(Color.primary.opacity(isHovered ? 0.08 : 0.05))
        case .destructive:
            return AnyShapeStyle(Color.red.opacity(isHovered ? 0.14 : 0.08))
        }
    }

    private var iconBackground: some ShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(Color.white.opacity(0.18))
        case .secondary:
            return AnyShapeStyle(Color.primary.opacity(isHovered ? 0.10 : 0.06))
        case .destructive:
            return AnyShapeStyle(Color.red.opacity(isHovered ? 0.18 : 0.12))
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.white.opacity(0.12)
        case .secondary:
            return Color.primary.opacity(isHovered ? 0.14 : 0.08)
        case .destructive:
            return Color.red.opacity(isHovered ? 0.28 : 0.18)
        }
    }

    private var borderWidth: CGFloat {
        style == .primary ? 0 : 1
    }
}
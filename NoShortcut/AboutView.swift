import SwiftUI

struct AboutView: View {
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var isInline: Bool { onClose != nil }

    var body: some View {
        VStack(spacing: isInline ? 12 : 16) {
            if isInline {
                HStack {
                    Button {
                        close()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            AppIconView(size: isInline ? 64 : 88)

            Text(AppInfo.name)
                .font(isInline ? .title3.weight(.semibold) : .title2.weight(.semibold))

            Text(AppInfo.versionString)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Developer: \(AppInfo.developer)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Block macOS keyboard shortcuts with customizable profiles.")
                .font(isInline ? .caption : .body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: isInline ? 260 : 320)

            Text("Requires Accessibility and Input Monitoring permissions.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("OK") {
                close()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: isInline ? .infinity : nil)
            .padding(.top, 4)
        }
        .padding(isInline ? 0 : 32)
        .frame(width: isInline ? nil : 380)
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
import SwiftUI

struct AppIconView: View {
    var size: CGFloat = 40

    private var cornerRadius: CGFloat {
        size * 0.225
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.11, blue: 0.16),
                            Color(red: 0.18, green: 0.20, blue: 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(Color.white.opacity(0.95), lineWidth: max(1.5, size * 0.045))
                .frame(width: size * 0.58, height: size * 0.58)

            Image(systemName: "command")
                .font(.system(size: size * 0.30, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

#if canImport(AppKit)
import AppKit

extension AppIconView {
    static func renderNSImage(size: CGFloat) -> NSImage {
        let view = AppIconView(size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
    }
}
#endif
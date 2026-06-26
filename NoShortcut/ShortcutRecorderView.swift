import SwiftUI
import AppKit

struct ShortcutRecorderView: View {
    var onComplete: (Shortcut?) -> Void

    init(onComplete: @escaping (Shortcut?) -> Void) {
        self.onComplete = onComplete
    }

    @State private var isRecording = false
    @State private var recorded: Shortcut?
    @State private var statusMessage = "Click the button and press your desired key combination."

    var body: some View {
        VStack(spacing: 24) {
            Text("Record Shortcut")
                .font(.title2.bold())

            if let shortcut = recorded {
                VStack(spacing: 8) {
                    Text("Recorded:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shortcut.displayString)
                        .font(.system(size: 42, weight: .semibold, design: .monospaced))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 32)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else if isRecording {
                VStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 56))
                        .symbolEffect(.pulse, options: .repeating)

                    Text("Press keys now…")
                        .font(.headline)

                    Text("Modifiers + key (⌘Q, ⌥⇧F, etc.)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text(statusMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    stopRecording(cancel: true)
                }
                .keyboardShortcut(.cancelAction)

                if isRecording {
                    Button("Done") {
                        stopRecording(cancel: false)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(recorded == nil)
                } else {
                    Button {
                        startRecording()
                    } label: {
                        Label("Record Shortcut", systemImage: "record.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.space, modifiers: [])
                }

                if recorded != nil {
                    Button("Use This Shortcut") {
                        if let s = recorded {
                            onComplete(s)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(32)
        .frame(width: 420)
        .onAppear {
            // Focus the window so the local monitor works immediately
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onDisappear {
            stopRecording(cancel: true)
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recorded = nil
        statusMessage = "Listening for keys. Press Esc to cancel."

        // Capture the next key down event while the window is key.
        let token = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            // Ignore pure modifier events (they come as flagsChanged mostly)
            let keyCode = event.keyCode
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape cancels
            if keyCode == 53 { // kVK_Escape
                stopRecording(cancel: true)
                return nil
            }

            // We require at least one modifier for a shortcut.
            // (Allowing bare keys would block normal typing — bad idea.)
            if mods.isEmpty {
                statusMessage = "Please include at least one modifier (⌘ ⌥ ⌃ ⇧)."
                // Still let the key through for this recorder window
                return event
            }

            let display = KeyCodeMapper.displayString(from: event)

            let shortcut = Shortcut(
                id: UUID(),
                modifiers: Int(mods.rawValue),
                keyCode: keyCode,
                displayString: display
            )

            self.recorded = shortcut
            self.statusMessage = "Captured: \(display). Press Enter or click Done."

            // We consume the event so it doesn't type into any background field.
            return nil
        }

        // Store monitor so we can remove it later
        // Because the struct is value type, we keep it in a tiny holder.
        RecorderHolder.shared.currentMonitor = token
    }

    private func stopRecording(cancel: Bool) {
        isRecording = false

        if let token = RecorderHolder.shared.currentMonitor {
            NSEvent.removeMonitor(token)
            RecorderHolder.shared.currentMonitor = nil
        }

        if cancel {
            recorded = nil
            onComplete(nil)
        } else {
            // Let the parent decide — the button "Use This Shortcut" already handles it.
            // If user just hits Done with no shortcut, treat as cancel.
            if recorded == nil {
                onComplete(nil)
            }
            // Otherwise the "Use" button will call onComplete.
        }
    }
}

// Small holder because we need mutable reference to the monitor token from value-type View.
private final class RecorderHolder {
    static let shared = RecorderHolder()
    var currentMonitor: Any?
    private init() {}
}
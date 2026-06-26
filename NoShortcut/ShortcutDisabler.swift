import Foundation
import AppKit
import CoreGraphics

final class ShortcutDisabler {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var shortcuts: [Shortcut] = []
    private var blockingMode: ProfileBlockingMode = .selectedOnly
    private(set) var isEnabled: Bool = false

    var isTapInstalled: Bool { eventTap != nil }

    /// Update what to block.
    ///
    /// - `shortcuts`: blocklist in `.selectedOnly`, allowlist in `.allExcept`
    /// - `mode`: how the profile interprets the shortcut list
    /// - `enabled`: whether the whole disabler is active right now
    func update(shortcuts: [Shortcut], mode: ProfileBlockingMode, enabled: Bool) {
        self.shortcuts = shortcuts
        self.blockingMode = mode

        if enabled {
            installTap()
        } else {
            removeTap()
        }

        isEnabled = enabled && eventTap != nil
    }

    func disable() {
        update(shortcuts: [], mode: .selectedOnly, enabled: false)
    }

    // MARK: - Tap management

    private func installTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }

        // Listen for key down + modifier changes
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) |
                   CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            print("⚠️ Failed to create CGEventTap. Enable Accessibility and Input Monitoring in Privacy & Security.")
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("✅ Event tap installed — shortcut blocking active")
    }

    private func removeTap() {
        guard let tap = eventTap else { return }

        CGEvent.tapEnable(tap: tap, enable: false)

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        CFMachPortInvalidate(tap)
        eventTap = nil

        print("🛑 Event tap removed")
    }

    // MARK: - Matching

    fileprivate func shouldBlock(keyCode: UInt16, cgFlags: CGEventFlags) -> Bool {
        let pressed = cgEventFlagsToModifierFlags(cgFlags)

        switch blockingMode {
        case .selectedOnly:
            return matches(shortcuts, keyCode: keyCode, pressed: pressed)

        case .all:
            return isGlobalShortcutCandidate(keyCode: keyCode, pressed: pressed)

        case .allExcept:
            guard isGlobalShortcutCandidate(keyCode: keyCode, pressed: pressed) else { return false }
            return !matches(shortcuts, keyCode: keyCode, pressed: pressed)
        }
    }

    private func isGlobalShortcutCandidate(keyCode: UInt16, pressed: NSEvent.ModifierFlags) -> Bool {
        if pressed.contains(.command) ||
           pressed.contains(.control) ||
           pressed.contains(.option) {
            return true
        }
        return isFunctionKey(keyCode)
    }

    private func matches(_ list: [Shortcut], keyCode: UInt16, pressed: NSEvent.ModifierFlags) -> Bool {
        for shortcut in list {
            let required = shortcut.modifierFlags
            if keyCode == shortcut.keyCode && pressed.isSuperset(of: required) {
                return true
            }
        }
        return false
    }

    private func isFunctionKey(_ keyCode: UInt16) -> Bool {
        // F1-F12 keycodes on macOS
        let functionKeyCodes: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        return functionKeyCodes.contains(keyCode)
    }
}

// MARK: - Free function callback (required by CGEventTap)

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }

    let disabler = Unmanaged<ShortcutDisabler>.fromOpaque(refcon).takeUnretainedValue()

    if type == .keyDown || type == .flagsChanged {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if disabler.shouldBlock(keyCode: keyCode, cgFlags: flags) {
            // Consume the event so apps and system never see it.
            return nil
        }
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - Flags conversion

private func cgEventFlagsToModifierFlags(_ flags: CGEventFlags) -> NSEvent.ModifierFlags {
    var result: NSEvent.ModifierFlags = []

    if flags.contains(.maskCommand)   { result.insert(.command) }
    if flags.contains(.maskAlternate) { result.insert(.option) }
    if flags.contains(.maskControl)   { result.insert(.control) }
    if flags.contains(.maskShift)     { result.insert(.shift) }

    // We deliberately ignore capsLock, numericPad, function, etc.
    return result.intersection(.deviceIndependentFlagsMask)
}
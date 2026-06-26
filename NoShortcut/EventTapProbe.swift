import CoreGraphics
import Foundation

enum EventTapProbe {
    private static var cachedResult: Bool?
    private static var cachedAt: Date?
    private static let cacheLifetime: TimeInterval = 2.0

    static func canCreateEventTap(forceRefresh: Bool = false) -> Bool {
        if !forceRefresh,
           let cachedResult,
           let cachedAt,
           Date().timeIntervalSince(cachedAt) < cacheLifetime {
            return cachedResult
        }

        return refreshProbe()
    }

    static func invalidateCache() {
        cachedResult = nil
        cachedAt = nil
    }

    @discardableResult
    private static func refreshProbe() -> Bool {
        let result = probe()
        cachedResult = result
        cachedAt = Date()
        return result
    }

    private static func probe() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: probeCallback,
            userInfo: nil
        ) else {
            return false
        }

        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        return true
    }
}

private func probeCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    Unmanaged.passUnretained(event)
}
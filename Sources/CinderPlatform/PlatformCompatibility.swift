import Foundation

public enum PlatformCompatibility {
    public static var osDescription: String { ProcessInfo.processInfo.operatingSystemVersionString }
    public static var validationStatus: String { "macOS runtime verification pending" }
    // Gate APIs newer than the macOS 14 deployment target; runtime support needs OS-specific verification.
}

@MainActor public final class SleepPrevention {
    private var token: NSObjectProtocol?
    public init() {}
    public func begin() {
        guard token == nil else { return }
        token = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled], reason: "Cinder audio playback")
    }
    public func end() {
        if let token { ProcessInfo.processInfo.endActivity(token) }
        token = nil
    }
}

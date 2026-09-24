import Foundation

public enum Identity {
    public static let version = "1.0.0-dev"
    public static let build = "5.0.0"
    public static let minimumMacOS = "27.0"
    public static let releaseChannel = "dev"
    public static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Cinder (Dev)"
    public static let bundleID = Bundle.main.bundleIdentifier ?? "local.chu.cinder"
    public static let settingsDirectory = Bundle.main.object(forInfoDictionaryKey: "CinderSettingsDirectory") as? String ?? "Swinder"
}

public struct SessionSettings: Codable, Equatable, Sendable {
    public var hours: Double = 30
    public var gainDB: Double = GainPolicy.initial
    public var resetGainDB: Double? = nil
    public var keepAwake = true
    public var program: PlaybackProgram? = nil
    public var musicSource: MusicSource? = nil
    public var musicPreset: PresetMusic? = nil
    public var playbackPlan: PlaybackPlan? = nil
    public var selectedPlan: PlaybackPlan { playbackPlan ?? PlaybackPlan() }
    public var selectedProgram: PlaybackProgram { program ?? .fullCycle }
    public var selectedMusicSource: MusicSource { musicSource ?? .library }
    public var selectedMusicPreset: PresetMusic { musicPreset ?? .balanced }
    public var customDurationMinutes: Int { (try? PlaybackDuration.minutes(fromHours: hours)) ?? 1800 }
    public var plannedSessions: [Int] { (try? selectedPlan.sessions(customMinutes: customDurationMinutes)) ?? [customDurationMinutes] }
    public var durationMinutes: Int {
        switch selectedPlan.mode {
        case .custom: return customDurationMinutes
        case .continuous40: return PlaybackPlan.targetMinutes
        case .split40: return selectedPlan.sessionMinutes
        }
    }
    public var planElapsedMinutes: Int { (try? selectedPlan.elapsedMinutes(customMinutes: customDurationMinutes)) ?? customDurationMinutes }
    public var durationSeconds: Double { Double(durationMinutes * 60) }
    public init() {}
    public func validatePlayback() throws {
        try validate()
        try selectedPlan.validatePlayback(customMinutes: customDurationMinutes, program: selectedProgram)
    }
    public func validate() throws {
        _ = try PlaybackDuration.minutes(fromHours: hours)
        try selectedPlan.validate()
        try GainPolicy.validate(gainDB)
        if let resetGainDB { try GainPolicy.validate(resetGainDB) }
    }
}

public enum CinderError: LocalizedError {
    case invalidDuration, invalidGain, noDevice, deviceChanged, audio(String)
    public var errorDescription: String? {
        switch self {
        case .invalidDuration: return "Choose 1 minute to 1000 hours in whole minutes."
        case .invalidGain: return "Gain must be between −60 and 0 dB."
        case .noDevice: return "Select an output device first."
        case .deviceChanged: return "The selected output changed or disconnected. Playback stopped."
        case .audio(let message): return message
        }
    }
}

public enum PlaybackState: String {
    case idle, preparing, playing, pausing, paused, stopping, completed, failed
    public var locksSettings: Bool { [.preparing, .playing, .pausing, .paused, .stopping].contains(self) }
}

public enum Cycle {
    public static let seconds = [900, 300, 900, 900, 300, 300]
    public static let names = ["Pink-like noise", "Rest", "Band-limited noise", "Music / pink noise", "Gentle sweep", "Rest"]
    public static func step(at seconds: Double) -> Int {
        var remaining = max(0, seconds).truncatingRemainder(dividingBy: 3600)
        for (index, duration) in self.seconds.enumerated() {
            if remaining < Double(duration) { return index }
            remaining -= Double(duration)
        }
        return 0
    }
    public static func time(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }
}

public struct AudioSnapshot: Equatable {
    public var elapsed: Double = 0
    public var sound: Double = 0
    public var peakDB: Double = -.infinity
    public var rmsDB: Double = -.infinity
    public var paused = false
    public var finished = false
    public init() {}
}

public struct Release: Decodable, Identifiable {
    public var id: String { version }
    public let version: String
    public let changes: [String: [Change]]
    public struct Change: Decodable { public let type: String; public let text: String }
}
public struct Changelog: Decodable { public let releases: [Release] }

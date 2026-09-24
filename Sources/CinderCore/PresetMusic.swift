import Foundation

public enum MusicSource: String, Codable, CaseIterable, Sendable {
    case library, preset
    public var label: String { self == .library ? "My music" : "Preset Music" }
}

/// Stable persisted identifiers for the bundled lossless arrangements.
public enum PresetMusic: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic, balanced, electronic, acoustic, pop, rock, metal
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .classic: return "Classic"
        case .balanced: return "Balanced"
        case .electronic: return "Electronic"
        case .acoustic: return "Acoustic"
        case .pop: return "POP"
        case .rock: return "Rock"
        case .metal: return "Metal"
        }
    }
    public var bars: Int {
        switch self {
        case .classic: return 21
        case .balanced: return 16
        case .electronic: return 28
        case .acoustic: return 24
        case .pop: return 28
        case .rock: return 32
        case .metal: return 40
        }
    }
    public var bpm: Int {
        switch self {
        case .classic: return 90
        case .balanced: return 100
        case .electronic: return 112
        case .acoustic: return 96
        case .pop: return 112
        case .rock: return 128
        case .metal: return 160
        }
    }
    public var loopSeconds: Double { Double(bars * 4 * 60) / Double(bpm) }
    public var filename: String { "preset-\(rawValue).flac" }
    public var descriptionKey: String {
        switch self {
        case .classic: return "Developing orchestral themes, expressive piano and harp, with seven gentle frequency-focus sections."
        case .balanced: return "Warm electric piano, connected chords and a restrained rhythm with room for the melody."
        case .electronic: return "Warm synth chords, a deep syncopated bass groove and spacious electronic melodies."
        case .acoustic: return "Resonant fingerstyle guitar, a singing top line and gentle piano with natural space."
        case .pop: return "A lyrical pop melody, piano and guitar, a quiet bridge and a fuller return."
        case .rock: return "Dramatic guitar and bass riffs, piano contrasts and a building final section."
        case .metal: return "Weighty muted riffs, sustained power chords and contrasting half-time passages."
        }
    }
}

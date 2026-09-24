import Foundation

public enum PlaybackProgram: String, Codable, CaseIterable, Sendable {
    case fullCycle, pink, band, music, sweep
    public var step: Int32 {
        switch self {
        case .fullCycle: return -1
        case .pink: return 0
        case .band: return 2
        case .music: return 3
        case .sweep: return 4
        }
    }
    public var label: String {
        switch self {
        case .fullCycle: return "Full cycle (60 min)"
        case .pink: return "Pink-like noise"
        case .band: return "Band-limited noise"
        case .music: return "Music"
        case .sweep: return "Gentle sweep"
        }
    }
    public var usesMusic: Bool { self == .fullCycle || self == .music }
}

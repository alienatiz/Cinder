import Foundation

/// A saved configuration, never an armed timer or a resumable playback job.
public struct PlaybackPlan: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case continuous40, split40, custom
        public var label: String {
            switch self {
            case .continuous40: return "40 hours · continuous"
            case .split40: return "40 hours · split"
            case .custom: return "Custom duration"
            }
        }
    }
    public static let targetMinutes = 40 * 60
    public static let maximumRestMinutes = 7 * 24 * 60
    public var mode: Mode
    public var sessionMinutes: Int
    public var restMinutes: Int

    public init(mode: Mode = .custom, sessionMinutes: Int = 240, restMinutes: Int = 60) {
        self.mode = mode; self.sessionMinutes = sessionMinutes; self.restMinutes = restMinutes
    }
    public func validate() throws {
        guard (1...Self.targetMinutes).contains(sessionMinutes),
              (0...Self.maximumRestMinutes).contains(restMinutes) else {
            throw CinderError.audio("Use 1 minute–40 hours per session and 0–7 days between sessions.")
        }
    }
    public func sessions(customMinutes: Int) throws -> [Int] {
        try validate()
        _ = try PlaybackDuration.hours(fromMinutes: customMinutes)
        switch mode {
        case .custom: return [customMinutes]
        case .continuous40: return [Self.targetMinutes]
        case .split40:
            let count = Self.targetMinutes / sessionMinutes
            let remainder = Self.targetMinutes % sessionMinutes
            return Array(repeating: sessionMinutes, count: count) + (remainder == 0 ? [] : [remainder])
        }
    }
    public func validatePlayback(customMinutes: Int, program: PlaybackProgram) throws {
        let runs = try sessions(customMinutes: customMinutes)
        if program == .fullCycle && runs.contains(where: { $0 < 60 }) {
            throw CinderError.audio(mode == .split40
                ? "Every session, including the last, needs 60 minutes for a full cycle. Adjust the split or choose one function."
                : "A full cycle needs 60 minutes. Choose one function for a shorter session.")
        }
    }
    public func elapsedMinutes(customMinutes: Int) throws -> Int {
        let runs = try sessions(customMinutes: customMinutes)
        return runs.reduce(0, +) + (mode == .split40 ? (runs.count - 1) * restMinutes : 0)
    }
}

/// In-memory progress. Rest begins at actual completion, so pauses/preparation
/// cannot shorten the requested interval. Never serialize or auto-resume it.
public struct PlaybackPlanRun: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case playing, resting(until: Date), completed, cancelled
    }
    public let sessions: [Int]
    public let restMinutes: Int
    public private(set) var completedSessions = 0
    public private(set) var completedMinutes = 0
    public private(set) var phase: Phase = .playing

    public init(plan: PlaybackPlan, customMinutes: Int, program: PlaybackProgram) throws {
        try plan.validatePlayback(customMinutes: customMinutes, program: program)
        sessions = try plan.sessions(customMinutes: customMinutes)
        restMinutes = plan.mode == .split40 ? plan.restMinutes : 0
    }
    public var isActive: Bool {
        switch phase { case .playing, .resting: return true; default: return false }
    }
    public var currentMinutes: Int { sessions[min(completedSessions, sessions.count - 1)] }
    public var nextStart: Date? { if case .resting(let date) = phase { return date }; return nil }
    public mutating func finishSession(at now: Date) {
        guard phase == .playing else { return }
        completedMinutes += currentMinutes
        completedSessions += 1
        phase = completedSessions == sessions.count ? .completed : .resting(until: now.addingTimeInterval(Double(restMinutes * 60)))
    }
    public mutating func startNextSession(at now: Date) -> Bool {
        guard let due = nextStart else { return false }
        switch ScheduleRules.due(target: due, now: now) {
        case "due": phase = .playing; return true
        case "missed": phase = .cancelled; return false
        default: return false
        }
    }
    public mutating func cancel() { if isActive { phase = .cancelled } }
}

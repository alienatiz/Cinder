import Foundation

/// Planned signal stages, not measured acoustic output or detected musical silence.
public struct PlaybackTiming: Equatable, Sendable {
    public let sessionSeconds: Double
    public let signalSeconds: Double
    public let betweenSessionRestSeconds: Double
    public var cycleRestSeconds: Double { sessionSeconds - signalSeconds }
    public var totalSeconds: Double { sessionSeconds + betweenSessionRestSeconds }

    public init(plan: PlaybackPlan, customMinutes: Int, program: PlaybackProgram) throws {
        let sessions = try plan.sessions(customMinutes: customMinutes)
        sessionSeconds = Double(sessions.reduce(0, +) * 60)
        signalSeconds = sessions.reduce(0) { $0 + Self.signalTime(elapsed: Double($1 * 60), program: program) }
        betweenSessionRestSeconds = plan.mode == .split40 ? Double(max(0, sessions.count - 1) * plan.restMinutes * 60) : 0
    }

    public static func signalTime(elapsed: Double, program: PlaybackProgram) -> Double {
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        guard program == .fullCycle else { return elapsed }
        let cycle = Double(Cycle.seconds.reduce(0, +))
        let active = Cycle.seconds.enumerated().reduce(0) { $0 + ([1, 5].contains($1.offset) ? 0 : $1.element) }
        var result = floor(elapsed / cycle) * Double(active)
        var remaining = elapsed.truncatingRemainder(dividingBy: cycle)
        for (index, seconds) in Cycle.seconds.enumerated() {
            let portion = min(remaining, Double(seconds))
            if index != 1 && index != 5 { result += portion }
            remaining -= portion
            if remaining <= 0 { break }
        }
        return result
    }
}

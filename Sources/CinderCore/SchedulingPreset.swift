import Foundation

/// Portable local-clock template, not an armed reservation or an audio preset.
public struct SchedulingPreset: Codable, Identifiable {
    public var schema_version = 1
    public var kind = "cinder_scheduling_preset"
    public var name: String
    public var time: String
    public var repeat_days: Int
    public var sessions: Int
    public var id: String { name }
    public init(name: String, time: String, repeatDays: Int, sessions: Int) {
        self.name = name; self.time = time; repeat_days = repeatDays; self.sessions = sessions
    }
    public func validate() throws {
        guard schema_version == 1, kind == "cinder_scheduling_preset",
              (1...80).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count),
              time.range(of: "^([01][0-9]|2[0-3]):[0-5][0-9]$", options: .regularExpression) != nil,
              (0...365).contains(repeat_days), (1...365).contains(sessions),
              repeat_days != 0 || sessions == 1 else { throw CinderError.audio("Invalid scheduling preset.") }
    }
    public func nextDate(after now: Date, calendar: Calendar = .current) throws -> Date {
        try validate()
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard let date = calendar.nextDate(after: now, matching: DateComponents(hour: parts[0], minute: parts[1], second: 0), matchingPolicy: .nextTime) else {
            throw CinderError.audio("Cannot resolve scheduling preset time.")
        }
        return date
    }
}

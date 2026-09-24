import Foundation

public struct PresetDocument: Codable, Identifiable, Sendable {
    public var id: String { name ?? "Preset" }
    public var schema_version = 1
    public var kind = "cinder_preset"
    public var name: String?
    public var settings: Values
    public struct Values: Codable, Sendable {
        public var hours: Double
        public var gain_db: Double
        public var music: [String]
        public var dac_model: String?
        public var time: String
        public var repeat_days: Int
        public var sessions: Int
        public var keep_awake: Bool
        public var program: PlaybackProgram? = nil
        public var music_source: MusicSource? = nil
        public var music_preset: PresetMusic? = nil
        public var selectedMusicSource: MusicSource { music_source ?? .library }
        public init(hours: Double, gain: Double, music: [String], dac: String?, time: String, days: Int, sessions: Int, awake: Bool) {
            self.hours = hours; gain_db = gain; self.music = music; dac_model = dac
            self.time = time; repeat_days = days; self.sessions = sessions; keep_awake = awake
        }
    }
    public init(name: String, settings: Values) { self.name = name; self.settings = settings }
    public func validate() throws {
        var session = SessionSettings(); session.hours = settings.hours; session.gainDB = Double(settings.gain_db)
        try session.validate()
        guard schema_version == 1, kind == "cinder_preset", (1...80).contains((name ?? "Preset").count),
              settings.music.count <= 100, settings.music.allSatisfy({ $0.utf8.count < 4096 }),
              settings.time.range(of: "^([01][0-9]|2[0-3]):[0-5][0-9]$", options: .regularExpression) != nil,
              (0...365).contains(settings.repeat_days), (1...365).contains(settings.sessions) else {
            throw CinderError.audio("Invalid preset.")
        }
    }
}

public struct ThemeDocument: Codable, Identifiable, Sendable {
    public var schema_version: Int
    public var kind: String
    public var id: String
    public var name: String
    public var colors: [String: String]
    public static let tokens = ["window.background", "text.primary", "text.secondary", "accent", "warning", "control.background", "control.foreground", "selection.background", "selection.foreground", "meter.background", "meter.track", "meter.fill", "meter.text"]
    public func validate() throws {
        guard schema_version == 1, kind == "cinder_theme", (1...80).contains(name.count),
              id.range(of: "^[a-z0-9][a-z0-9-]{0,63}$", options: .regularExpression) != nil,
              Set(colors.keys) == Set(Self.tokens), colors.values.allSatisfy(Self.validHex) else {
            throw CinderError.audio("Invalid theme: expected Cinder theme v1 and #RRGGBB colors.")
        }
    }
    public var prefersDark: Bool {
        let value = UInt32((colors["window.background"] ?? "#17212B").dropFirst(), radix: 16) ?? 0
        let brightness = 0.2126 * Double((value >> 16) & 255) + 0.7152 * Double((value >> 8) & 255) + 0.0722 * Double(value & 255)
        return brightness < 128
    }
    public static func validHex(_ hex: String) -> Bool {
        hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil
    }
}

public enum ScheduleRules {
    /// Tomorrow's local calendar date, retaining today's hour/minute (not a fixed 24-hour offset).
    public static func tomorrow(at date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let clock = calendar.dateComponents([.hour, .minute], from: date)
        return calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0, second: 0,
                             of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first) ?? day
    }
    public static func nextDawn(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(hour: 2, minute: 0), matchingPolicy: .nextTime) ?? date.addingTimeInterval(86400)
    }
    public static func next(anchor: Date, days: Int, after: Date, calendar: Calendar = .current) throws -> Date {
        guard (1...365).contains(days) else { throw CinderError.audio("Repeat interval must be 1–365 days.") }
        let elapsed = calendar.dateComponents([.day], from: anchor, to: after).day ?? 0
        var step = max(1, elapsed / days)
        let clock = calendar.dateComponents([.hour, .minute], from: anchor)
        for _ in 0..<740 {
            if let candidate = calendar.date(byAdding: .day, value: step * days, to: anchor), candidate > after,
               calendar.component(.hour, from: candidate) == clock.hour,
               calendar.component(.minute, from: candidate) == clock.minute { return candidate }
            step += 1
        }
        throw CinderError.audio("Cannot find the next reservation.")
    }
    public static func due(target: Date, now: Date) -> String {
        now < target ? "waiting" : (now.timeIntervalSince(target) <= 60 ? "due" : "missed")
    }
}

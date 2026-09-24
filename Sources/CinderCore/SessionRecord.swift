import Foundation

public enum SessionOutcome: String, Codable, Sendable, CaseIterable {
    case active, completed, stopped, deviceChanged, failed, appQuit, interrupted, missedSchedule
    public var label: String {
        switch self {
        case .active: return "In progress"
        case .completed: return "Completed"
        case .stopped: return "Stopped by user"
        case .deviceChanged: return "Output changed or disconnected"
        case .failed: return "Playback failed"
        case .appQuit: return "App quit"
        case .interrupted: return "Interrupted before last close"
        case .missedSchedule: return "Scheduled start missed"
        }
    }
}

public enum SessionPhase: String, Codable, Sendable { case preparing, playing, paused, resting }

public struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var updatedAt: Date
    public var endedAt: Date?
    public let outputName: String
    public let settings: SessionSettings
    public var outcome: SessionOutcome = .active
    public var completedSessions = 0
    public var elapsedSeconds: Double = 0
    public var signalSeconds: Double = 0
    public var betweenRestSeconds: Double = 0
    public var pausedSeconds: Double = 0
    public var preparingSeconds: Double = 0
    public var minimumGainDB: Double
    public var maximumGainDB: Double
    public var cycleRestSeconds: Double { max(0, elapsedSeconds - signalSeconds) }
    public var plannedSessions: Int { settings.plannedSessions.count }

    public init(id: UUID = UUID(), startedAt: Date, outputName: String, settings: SessionSettings) {
        self.id = id; self.startedAt = startedAt; updatedAt = startedAt
        self.outputName = outputName; self.settings = settings
        minimumGainDB = settings.gainDB; maximumGainDB = settings.gainDB
    }
    public func validate() throws {
        try settings.validate()
        try GainPolicy.validate(minimumGainDB); try GainPolicy.validate(maximumGainDB)
        let times = [elapsedSeconds, signalSeconds, betweenRestSeconds, pausedSeconds, preparingSeconds]
        guard outputName.utf8.count <= 4096,
              [startedAt, updatedAt, endedAt ?? updatedAt].allSatisfy({ $0.timeIntervalSince1970.isFinite }),
              times.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1_000_000_000 }),
              signalSeconds <= elapsedSeconds, minimumGainDB <= maximumGainDB,
              (0...plannedSessions).contains(completedSessions),
              (outcome == .active) == (endedAt == nil) else {
            throw CinderError.audio("Invalid session record.")
        }
    }
}

/// Updated on the control actor, never from an audio render callback.
public struct SessionRecorder: Sendable {
    public private(set) var record: SessionRecord
    private var phase: SessionPhase = .preparing
    private var lastUptime: Double
    private var completedElapsed: Double = 0
    private var completedSignal: Double = 0
    private var currentElapsed: Double = 0
    private var currentSignal: Double = 0

    public init(settings: SessionSettings, outputName: String, now: Date, uptime: Double) {
        record = SessionRecord(startedAt: now, outputName: outputName, settings: settings)
        lastUptime = uptime
    }
    public mutating func update(snapshot: AudioSnapshot, phase: SessionPhase, gain: Double, now: Date, uptime: Double) {
        guard record.outcome == .active else { return }
        let delta = uptime.isFinite && lastUptime.isFinite ? max(0, uptime - lastUptime) : 0
        switch self.phase {
        case .preparing: record.preparingSeconds += delta
        case .paused: record.pausedSeconds += delta
        case .resting: record.betweenRestSeconds += delta
        case .playing: break
        }
        lastUptime = uptime; self.phase = phase; record.updatedAt = now
        let sessions = record.settings.plannedSessions
        let limit = Double(sessions[min(record.completedSessions, sessions.count - 1)] * 60)
        if snapshot.elapsed.isFinite { currentElapsed = min(limit, max(currentElapsed, snapshot.elapsed)) }
        if snapshot.sound.isFinite { currentSignal = min(currentElapsed, max(currentSignal, snapshot.sound)) }
        record.elapsedSeconds = completedElapsed + currentElapsed
        record.signalSeconds = completedSignal + currentSignal
        if (try? GainPolicy.validate(gain)) != nil {
            record.minimumGainDB = min(record.minimumGainDB, gain)
            record.maximumGainDB = max(record.maximumGainDB, gain)
        }
    }
    public mutating func completeSession() {
        guard record.outcome == .active, currentElapsed > 0,
              record.completedSessions < record.plannedSessions else { return }
        completedElapsed = record.elapsedSeconds; completedSignal = record.signalSeconds
        record.completedSessions += 1; currentElapsed = 0; currentSignal = 0
    }
    public mutating func finish(_ outcome: SessionOutcome, at now: Date) {
        guard record.outcome == .active, outcome != .active else { return }
        record.outcome = outcome; record.endedAt = now; record.updatedAt = now
    }
}

public struct SessionHistory: Codable, Equatable, Sendable {
    public static let limit = 500
    public var schemaVersion = 1
    public private(set) var records: [SessionRecord] = []
    public init() {}
    public mutating func upsert(_ record: SessionRecord) {
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        records.sort { $0.startedAt > $1.startedAt }
        if records.count > Self.limit { records.removeLast(records.count - Self.limit) }
    }
    public mutating func recoverInterrupted() -> Bool {
        var changed = false
        for index in records.indices where records[index].outcome == .active {
            records[index].outcome = .interrupted
            records[index].endedAt = records[index].updatedAt
            changed = true
        }
        return changed
    }
    public func validate() throws {
        guard schemaVersion == 1, records.count <= Self.limit,
              Set(records.map(\.id)).count == records.count else { throw CinderError.audio("Invalid session history.") }
        for record in records { try record.validate() }
    }
}

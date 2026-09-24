import XCTest
import CinderCore
import CinderStorage

final class SessionHistoryTests: XCTestCase {
    func testSplitSessionsAccumulateWithoutDoubleCountingAndSeparateWaits() throws {
        var settings = SessionSettings()
        settings.playbackPlan = PlaybackPlan(mode: .split40, sessionMinutes: 60, restMinutes: 30)
        let now = Date(timeIntervalSince1970: 1000)
        var recorder = SessionRecorder(settings: settings, outputName: "Test", now: now, uptime: 10)
        recorder.update(snapshot: AudioSnapshot(), phase: .playing, gain: -30, now: now, uptime: 12)
        var sample = AudioSnapshot(); sample.elapsed = 3600; sample.sound = 3000
        recorder.update(snapshot: sample, phase: .resting, gain: -20, now: now, uptime: 3612)
        recorder.completeSession(); recorder.completeSession()
        recorder.update(snapshot: AudioSnapshot(), phase: .preparing, gain: -40, now: now, uptime: 5412)
        recorder.update(snapshot: AudioSnapshot(), phase: .playing, gain: -30, now: now, uptime: 5415)
        sample.elapsed = 600; sample.sound = 600
        recorder.update(snapshot: sample, phase: .paused, gain: -30, now: now, uptime: 6015)
        recorder.update(snapshot: sample, phase: .playing, gain: -30, now: now, uptime: 6045)
        recorder.finish(.stopped, at: now)
        XCTAssertEqual(recorder.record.elapsedSeconds, 4200)
        XCTAssertEqual(recorder.record.signalSeconds, 3600)
        XCTAssertEqual(recorder.record.cycleRestSeconds, 600)
        XCTAssertEqual(recorder.record.betweenRestSeconds, 1800)
        XCTAssertEqual(recorder.record.preparingSeconds, 5)
        XCTAssertEqual(recorder.record.pausedSeconds, 30)
        XCTAssertEqual(recorder.record.completedSessions, 1)
        XCTAssertEqual(recorder.record.minimumGainDB, -40)
        XCTAssertEqual(recorder.record.maximumGainDB, -20)
        let finished = recorder.record
        recorder.update(snapshot: sample, phase: .playing, gain: 0, now: now, uptime: 9000)
        recorder.finish(.completed, at: now.addingTimeInterval(30))
        XCTAssertEqual(recorder.record, finished)
        try finished.validate()
    }
    func testRoundTripAndInterruptedRecoveryPreserveLastCheckpoint() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SessionHistoryStore(directory: root)
        XCTAssertTrue(try store.load().records.isEmpty)
        var record = SessionRecord(startedAt: Date(timeIntervalSince1970: 100), outputName: "Headphones", settings: SessionSettings())
        record.updatedAt = Date(timeIntervalSince1970: 200); record.elapsedSeconds = 90; record.signalSeconds = 80
        var history = SessionHistory(); history.upsert(record); try store.save(history)
        var recovered = try store.load(); XCTAssertTrue(recovered.recoverInterrupted())
        XCTAssertEqual(recovered.records.first?.endedAt, record.updatedAt)
        XCTAssertEqual(recovered.records.first?.elapsedSeconds, 90)
        XCTAssertEqual(recovered.records.first?.outcome, .interrupted)
        XCTAssertFalse(recovered.recoverInterrupted())
        try store.save(recovered); XCTAssertEqual(try store.load(), recovered)
    }
    func testBoundedHistoryAndInvalidSaveProtectLastGoodFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SessionHistoryStore(directory: root)
        var history = SessionHistory()
        for index in 0...SessionHistory.limit {
            history.upsert(SessionRecord(startedAt: Date(timeIntervalSince1970: Double(index)), outputName: "Output", settings: SessionSettings()))
        }
        XCTAssertEqual(history.records.count, 500)
        XCTAssertEqual(history.records.last?.startedAt, Date(timeIntervalSince1970: 1))
        try store.save(history); let saved = try Data(contentsOf: store.file)
        var invalid = history.records[0]; invalid.signalSeconds = 100
        history.upsert(invalid)
        XCTAssertThrowsError(try store.save(history))
        XCTAssertEqual(try Data(contentsOf: store.file), saved)
        try Data("invalid".utf8).write(to: store.file)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.file), Data("invalid".utf8))
    }
}

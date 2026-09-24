import XCTest
import CinderCore
import CinderStorage
@testable import CinderApp

final class SessionHistoryIntegrationTests: XCTestCase {
    @MainActor func testStopPreparingAndPausedRecordsOutcomeAndPersistsOnQuit() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SettingsStore(directory: root)
        let model = AppModel(storage: store)
        defer { model.shutdown(); try? FileManager.default.removeItem(at: root) }
        model.beginSessionRecord(); model.state = .preparing; model.stop()
        XCTAssertEqual(model.sessionHistory.records.first?.outcome, .stopped)
        model.beginSessionRecord(); model.state = .paused
        var sample = AudioSnapshot(); sample.elapsed = 120; sample.sound = 90
        model.updateSessionRecord(snapshot: sample, force: true)
        model.stop()
        model.historyWriter.flush()
        let records = try SessionHistoryStore(directory: root).load().records
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.allSatisfy { $0.outcome == .stopped })
        XCTAssertEqual(records.first?.elapsedSeconds, 120)
        XCTAssertEqual(records.first?.signalSeconds, 90)
        XCTAssertNil(model.sessionRecorder)
    }
    @MainActor func testDeviceFailureAndMissedRestPreserveRecordedProgress() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = AppModel(storage: SettingsStore(directory: root))
        defer { model.shutdown(); try? FileManager.default.removeItem(at: root) }
        model.beginSessionRecord(); model.state = .playing
        var sample = AudioSnapshot(); sample.elapsed = 200; sample.sound = 150
        model.updateSessionRecord(snapshot: sample)
        model.fail(CinderError.deviceChanged)
        XCTAssertEqual(model.sessionHistory.records.first?.outcome, .deviceChanged)
        XCTAssertEqual(model.sessionHistory.records.first?.elapsedSeconds, 200)
        model.settings.playbackPlan = PlaybackPlan(mode: .split40, sessionMinutes: 60, restMinutes: 0)
        model.beginSessionRecord()
        var run = try PlaybackPlanRun(plan: model.settings.selectedPlan, customMinutes: 60, program: .fullCycle)
        run.finishSession(at: Date().addingTimeInterval(-120))
        model.planRun = run; model.armed = run.nextStart; model.state = .completed
        model.checkSchedule()
        XCTAssertEqual(model.sessionHistory.records.first?.outcome, .missedSchedule)
        XCTAssertNil(model.armed)
        XCTAssertNil(model.sessionRecorder)
    }
    @MainActor func testInterruptedRecoveryAndCorruptFileDoNotStartOrOverwrite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = SettingsStore(directory: root)
        let historyStore = SessionHistoryStore(directory: root)
        var history = SessionHistory()
        history.upsert(SessionRecord(startedAt: Date(), outputName: "Old output", settings: SessionSettings()))
        try historyStore.save(history)
        let restored = AppModel(storage: storage)
        XCTAssertEqual(restored.sessionHistory.records.first?.outcome, .interrupted)
        XCTAssertEqual(restored.state, .idle); XCTAssertNil(restored.armed)
        restored.shutdown()
        let bad = Data("corrupted".utf8); try bad.write(to: historyStore.file)
        let model = AppModel(storage: storage)
        model.beginSessionRecord(); model.finishSessionRecord(.stopped); model.shutdown()
        XCTAssertNotNil(model.historyError)
        XCTAssertEqual(try Data(contentsOf: historyStore.file), bad)
        XCTAssertEqual(model.sessionHistory.records.count, 1)
    }
    @MainActor func testSummaryIncludesWaitsAndExcludesMusicPathsAndDeviceUID() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = AppModel(storage: SettingsStore(directory: root))
        defer { model.shutdown(); try? FileManager.default.removeItem(at: root) }
        model.language = "en"; model.selectedUID = "secret-device-uid"; model.music = ["/private/song.flac"]
        model.beginSessionRecord(); model.finishSessionRecord(.appQuit)
        let record = try XCTUnwrap(model.sessionHistory.records.first)
        let text = model.sessionSummary(record)
        XCTAssertTrue(text.contains("App quit")); XCTAssertTrue(text.contains("Signal stages"))
        XCTAssertTrue(text.contains("Paused time")); XCTAssertTrue(text.contains("App gain range"))
        XCTAssertFalse(text.contains(model.selectedUID)); XCTAssertFalse(text.contains("/private/song.flac"))
    }
}

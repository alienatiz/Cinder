import XCTest
import CinderCore
import CinderStorage

final class PlaybackPlanTests: XCTestCase {
    func testModesKeepCustomTimeAndUseExactlyFortyHours() throws {
        var settings = SessionSettings(); settings.hours = 8.5
        XCTAssertEqual(settings.durationMinutes, 510)
        settings.playbackPlan = PlaybackPlan(mode: .continuous40)
        XCTAssertEqual(settings.durationMinutes, 2400)
        XCTAssertEqual(settings.planElapsedMinutes, 2400)
        settings.playbackPlan = PlaybackPlan(mode: .split40, sessionMinutes: 180, restMinutes: 30)
        XCTAssertEqual(settings.plannedSessions, Array(repeating: 180, count: 13) + [60])
        XCTAssertEqual(settings.durationMinutes, 180)
        XCTAssertEqual(settings.planElapsedMinutes, 2790)
        settings.playbackPlan?.mode = .custom
        XCTAssertEqual(settings.durationMinutes, 510)
    }
    func testEverySplitPreservesTotalAndOnlyRestsBetweenSessions() throws {
        for minutes in 1...PlaybackPlan.targetMinutes {
            let plan = PlaybackPlan(mode: .split40, sessionMinutes: minutes, restMinutes: 7)
            let runs = try plan.sessions(customMinutes: 1)
            XCTAssertEqual(runs.reduce(0, +), 2400)
            XCTAssertTrue(runs.allSatisfy { (1...minutes).contains($0) })
            XCTAssertEqual(try plan.elapsedMinutes(customMinutes: 1), 2400 + (runs.count - 1) * 7)
        }
        for (session, rest) in [(0, 1), (2401, 1), (60, -1), (60, 10081)] {
            XCTAssertThrowsError(try PlaybackPlan(mode: .split40, sessionMinutes: session, restMinutes: rest).validate())
        }
    }
    func testFullCycleChecksTheShortFinalSession() throws {
        let shortLast = PlaybackPlan(mode: .split40, sessionMinutes: 70, restMinutes: 60)
        XCTAssertThrowsError(try shortLast.validatePlayback(customMinutes: 60, program: .fullCycle))
        XCTAssertNoThrow(try shortLast.validatePlayback(customMinutes: 60, program: .pink))
        XCTAssertNoThrow(try PlaybackPlan(mode: .split40, sessionMinutes: 180).validatePlayback(customMinutes: 60, program: .fullCycle))
        XCTAssertThrowsError(try PlaybackPlan(mode: .custom).validatePlayback(customMinutes: 30, program: .fullCycle))
    }
    func testAutomaticRestAndFinalCompletionWithoutExtraSession() throws {
        var run = try PlaybackPlanRun(plan: PlaybackPlan(mode: .split40, sessionMinutes: 180, restMinutes: 30), customMinutes: 60, program: .fullCycle)
        let beginning = Date(timeIntervalSince1970: 1_700_000_000)
        var now = beginning
        for index in 0..<14 {
            XCTAssertEqual(run.phase, .playing)
            now.addTimeInterval(Double(run.currentMinutes * 60))
            run.finishSession(at: now)
            let completed = run.completedMinutes
            run.finishSession(at: now) // duplicate completion must be harmless
            XCTAssertEqual(run.completedMinutes, completed)
            XCTAssertEqual(run.completedSessions, index + 1)
            if index < 13 {
                XCTAssertEqual(run.nextStart, now.addingTimeInterval(1800))
                XCTAssertFalse(run.startNextSession(at: now.addingTimeInterval(1799)))
                now.addTimeInterval(1800)
                XCTAssertTrue(run.startNextSession(at: now))
                XCTAssertFalse(run.startNextSession(at: now))
            }
        }
        XCTAssertEqual(run.phase, .completed)
        XCTAssertFalse(run.isActive)
        XCTAssertNil(run.nextStart)
        XCTAssertEqual(run.completedMinutes, 2400)
        XCTAssertEqual(now.timeIntervalSince(beginning), 2790 * 60)
        XCTAssertFalse(run.startNextSession(at: now.addingTimeInterval(86400)))
    }
    func testLateStartAndCancellationNeverResumeThePlan() throws {
        let plan = PlaybackPlan(mode: .split40, sessionMinutes: 240, restMinutes: 60)
        let finished = Date(timeIntervalSince1970: 1_700_000_000)
        var run = try PlaybackPlanRun(plan: plan, customMinutes: 60, program: .fullCycle)
        run.finishSession(at: finished)
        XCTAssertFalse(run.startNextSession(at: finished.addingTimeInterval(3661)))
        XCTAssertEqual(run.phase, .cancelled)
        XCTAssertFalse(run.isActive)
        XCTAssertFalse(run.startNextSession(at: finished.addingTimeInterval(3600)))
        for cancelDuringRest in [false, true] {
            var cancelled = try PlaybackPlanRun(plan: plan, customMinutes: 60, program: .fullCycle)
            if cancelDuringRest { cancelled.finishSession(at: finished) }
            cancelled.cancel()
            cancelled.finishSession(at: finished)
            XCTAssertFalse(cancelled.startNextSession(at: finished.addingTimeInterval(3600)))
            XCTAssertEqual(cancelled.completedSessions, cancelDuringRest ? 1 : 0)
        }
    }
    func testRestUsesActualCompletionAndAllowsZeroGap() throws {
        let finishedAfterPause = Date(timeIntervalSince1970: 1_800_000_000)
        var run = try PlaybackPlanRun(plan: PlaybackPlan(mode: .split40, sessionMinutes: 1200, restMinutes: 0), customMinutes: 60, program: .fullCycle)
        run.finishSession(at: finishedAfterPause)
        XCTAssertEqual(run.nextStart, finishedAfterPause)
        XCTAssertTrue(run.startNextSession(at: finishedAfterPause))
        run.finishSession(at: finishedAfterPause.addingTimeInterval(1200 * 60))
        XCTAssertEqual(run.phase, .completed)
        XCTAssertNil(run.nextStart)
    }
    func testLegacySettingsAndPresetPersistenceDoNotStoreAnActiveRun() throws {
        let legacy = Data(#"{"hours":8.5,"gainDB":-30,"keepAwake":false}"#.utf8)
        var settings = try JSONDecoder().decode(SessionSettings.self, from: legacy)
        XCTAssertNil(settings.playbackPlan)
        XCTAssertEqual(settings.selectedPlan.mode, .custom)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = SettingsStore(directory: root)
        try storage.save(settings)
        let plan = PlaybackPlan(mode: .split40, sessionMinutes: 180, restMinutes: 30)
        try storage.savePlaybackPlan(plan, customHours: 8.5)
        settings = try storage.load()
        XCTAssertEqual(settings.gainDB, -30)
        XCTAssertFalse(settings.keepAwake)
        XCTAssertEqual(settings.hours, 8.5)
        XCTAssertEqual(settings.playbackPlan, plan)
        let data = try JSONEncoder().encode(settings)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("completedSessions"))
        var preset = PresetDocument(name: "Split", settings: .init(hours: 8.5, gain: -30, music: [], dac: nil, time: "02:00", days: 0, sessions: 1, awake: false))
        preset.settings.playback_plan = plan
        for ext in ["json", "yaml"] {
            let path = root.appendingPathComponent("preset." + ext)
            try Documents.write(preset, to: path)
            let restored = try Documents.read(PresetDocument.self, at: path)
            try restored.validate()
            XCTAssertEqual(restored.settings.playback_plan, plan)
        }
        preset.settings.playback_plan?.restMinutes = -1
        XCTAssertThrowsError(try preset.validate())
    }
}

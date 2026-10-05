import XCTest
import CinderCore
import CinderStorage
@testable import CinderPlatform
@testable import CinderApp

final class MenuQuickPlayTests: XCTestCase {
    @MainActor private func fixture() throws -> (AppModel, SettingsStore) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SettingsStore(directory: directory)
        var settings = SessionSettings()
        settings.hours = 8.5; settings.gainDB = -42
        settings.playbackPlan = PlaybackPlan(mode: .split40, sessionMinutes: 180, restMinutes: 30)
        try store.save(settings)
        let model = AppModel(storage: store)
        // No real audio is started and no user preferences are read or written.
        model.devices = [OutputDevice(id: 0, uid: "test-output", name: "Test output", transport: 0)]
        return (model, store)
    }
    @MainActor private func cleanup(_ model: AppModel, _ store: SettingsStore) {
        model.shutdown()
        try? FileManager.default.removeItem(at: store.directory)
    }

    @MainActor func testOutputSelectionPersistsWithoutAnyWindow() async throws {
        let (model, store) = try fixture(); defer { cleanup(model, store) }
        model.outputRate = 192000
        model.selectOutput("test-output")
        try await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertEqual(try store.loadUI()?.outputUID, "test-output")
        XCTAssertEqual(model.outputRate, 0) // the synthetic device has no reported rate
        XCTAssertEqual(model.settings.gainDB, -42)
        XCTAssertEqual(model.state, .idle)
        XCTAssertNil(model.armed)
        XCTAssertNil(model.planRun)
        model.selectOutput("disconnected-output")
        XCTAssertEqual(model.selectedUID, "test-output")
    }

    @MainActor func testDurationEditKeepsOtherPreferencesAndDoesNotStart() throws {
        let (model, store) = try fixture(); defer { cleanup(model, store) }
        XCTAssertEqual(model.settings.selectedPlan.mode, .split40)
        XCTAssertEqual(model.settings.hours, 8.5)
        model.settings.gainDB = -55 // unsaved live gain must not be saved by a duration edit
        model.applyMinutes(125)
        XCTAssertEqual(model.settings.selectedPlan.mode, .custom)
        XCTAssertEqual(model.settings.durationMinutes, 125)
        XCTAssertEqual(model.settings.selectedPlan.sessionMinutes, 180)
        XCTAssertEqual(model.settings.selectedPlan.restMinutes, 30)
        XCTAssertEqual(model.settings.gainDB, -55)
        XCTAssertEqual(try store.load().gainDB, -42)
        XCTAssertEqual(try store.load().durationMinutes, 125)
        model.selectPlanMode(.continuous40)
        XCTAssertEqual(model.settings.durationMinutes, 2400)
        XCTAssertEqual(model.settings.customDurationMinutes, 125)
        model.selectPlanMode(.split40)
        XCTAssertEqual(model.settings.plannedSessions.count, 14)
        XCTAssertEqual(model.state, .idle)
        XCTAssertNil(model.armed)
        XCTAssertNil(model.planRun)
    }

    @MainActor func testOutputDetailsClearWithSelectionWithoutChangingGainOrPlayback() throws {
        let (model, store) = try fixture(); defer { cleanup(model, store) }
        model.selectOutput("test-output")
        XCTAssertNotNil(model.outputDetails)
        XCTAssertNil(model.outputDetails?.sampleRate)
        XCTAssertNil(model.outputDetails?.outputChannels)
        model.outputDetails = OutputDeviceDetails(manufacturer: "Previous device", sampleRate: 96000,
                                                 outputChannels: 8, availableSampleRates: [96000...96000])
        model.outputRate = 96000
        model.selectOutput("")
        XCTAssertNil(model.outputDetails)
        XCTAssertEqual(model.outputRate, 0)
        XCTAssertEqual(model.settings.gainDB, -42)
        XCTAssertEqual(model.state, .idle)
        XCTAssertFalse(model.canStart)
    }

    @MainActor func testPlaybackScheduleAndPreparationLockLiteEdits() throws {
        let (model, store) = try fixture(); defer { cleanup(model, store) }
        model.selectOutput("test-output")
        let original = model.settings
        for state in [PlaybackState.preparing, .playing, .pausing, .paused, .stopping] {
            model.state = state
            model.selectOutput(""); model.applyMinutes(60); model.selectPlanMode(.custom)
            model.start() // must not replace the current session
            XCTAssertEqual(model.state, state)
            XCTAssertEqual(model.selectedUID, "test-output")
            XCTAssertEqual(model.settings, original)
            XCTAssertFalse(model.canStart)
        }
        model.state = .idle; model.armed = Date().addingTimeInterval(600)
        model.selectOutput(""); model.applyMinutes(60)
        XCTAssertEqual(model.selectedUID, "test-output")
        XCTAssertEqual(model.settings, original)
        XCTAssertFalse(model.canStart)
        model.armed = nil; model.libraryBusy = true
        model.selectOutput(""); model.applyMinutes(60)
        XCTAssertEqual(model.selectedUID, "test-output")
        XCTAssertEqual(model.settings, original)
        XCTAssertFalse(model.canStart)
    }

    @MainActor func testStartAvailabilityUsesDurationMusicAndDeviceValidation() throws {
        let (model, store) = try fixture(); defer { cleanup(model, store) }
        model.selectOutput("test-output")
        model.applyMinutes(30)
        XCTAssertFalse(model.canStart) // full cycle needs at least an hour
        model.applyMinutes(60)
        XCTAssertTrue(model.canStart)
        model.settings.program = .music
        XCTAssertFalse(model.canStart) // no external tracks selected
        model.settings.musicSource = .preset
        XCTAssertTrue(model.canStart)
        model.selectOutput("")
        XCTAssertFalse(model.canStart)
        model.start()
        XCTAssertEqual(model.state, .idle)
        XCTAssertNotNil(model.error)
    }

    @MainActor func testSharedControlsFollowPlaybackTransitions() throws {
        let (model, store) = try fixture(); defer { cleanup(model, store) }
        model.selectOutput("test-output")
        let cases: [(PlaybackState, String, Bool, Bool, Bool, Bool)] = [
            // State, primary title, primary enabled, play enabled, pause/resume enabled, stop enabled.
            (.idle, "Start", true, true, false, false),
            (.preparing, "Start", false, false, false, true),
            (.playing, "Pause", true, false, true, true),
            (.pausing, "Start", false, false, false, true),
            (.paused, "Resume", true, true, true, true),
            (.stopping, "Start", false, false, false, false),
            (.completed, "Start", true, true, false, false),
            (.failed, "Start", true, true, false, false)
        ]
        for (state, title, primary, play, pause, stop) in cases {
            model.state = state
            XCTAssertEqual(model.primaryPlaybackTitle, title, state.rawValue)
            XCTAssertEqual(model.canPerformPrimaryPlaybackAction, primary, state.rawValue)
            XCTAssertEqual(model.canStartOrResume, play, state.rawValue)
            XCTAssertEqual(model.canTogglePause, pause, state.rawValue)
            XCTAssertEqual(model.canStop, stop, state.rawValue)
        }
    }

    @MainActor func testPrimaryActionDoesNotStartWhileUnavailable() throws {
        let (model, store) = try fixture(); defer { cleanup(model, store) }
        model.selectOutput("test-output")
        let original = model.settings
        let target = Date().addingTimeInterval(600)
        model.armed = target
        XCTAssertFalse(model.canPerformPrimaryPlaybackAction)
        XCTAssertFalse(model.canStartOrResume)
        XCTAssertTrue(model.canStop)
        model.performPrimaryPlaybackAction()
        XCTAssertEqual(model.armed, target)
        XCTAssertEqual(model.state, .idle)
        XCTAssertNil(model.planRun)
        model.armed = nil

        model.libraryBusy = true
        XCTAssertFalse(model.canPerformPrimaryPlaybackAction)
        model.performPrimaryPlaybackAction()
        XCTAssertEqual(model.state, .idle)
        model.libraryBusy = false

        model.selectOutput("")
        XCTAssertFalse(model.canPerformPrimaryPlaybackAction)
        model.performPrimaryPlaybackAction()
        XCTAssertEqual(model.state, .idle)
        XCTAssertEqual(model.settings, original)
        XCTAssertNil(model.planRun)

        for state in [PlaybackState.preparing, .pausing, .stopping] {
            model.state = state
            model.performPrimaryPlaybackAction()
            XCTAssertEqual(model.state, state)
        }
    }

    @MainActor func testStopCancelsRestingSplitPlanWithoutLaunchingAnotherSession() throws {
        let (model, store) = try fixture(); defer { cleanup(model, store) }
        model.selectOutput("test-output")
        var run = try PlaybackPlanRun(plan: model.settings.selectedPlan, customMinutes: 510, program: .fullCycle)
        run.finishSession(at: Date())
        model.planRun = run; model.armed = run.nextStart; model.state = .completed
        XCTAssertFalse(model.canStart)
        XCTAssertFalse(model.canPerformPrimaryPlaybackAction)
        XCTAssertFalse(model.canStartOrResume)
        XCTAssertTrue(model.canStop)
        model.start()
        XCTAssertEqual(model.planRun, run)
        XCTAssertEqual(model.armed, run.nextStart)
        model.stop()
        XCTAssertEqual(model.planRun?.phase, .cancelled)
        XCTAssertNil(model.armed)
        XCTAssertFalse(model.isLocked)
        XCTAssertTrue(model.canStart)
        XCTAssertFalse(model.canStop)
    }
}

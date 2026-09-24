import XCTest
import CinderCore
import CinderStorage
@testable import CinderApp

final class UpdateChannelTests: XCTestCase {
    @MainActor func testStableChoiceSurvivesRelaunchWithoutRelabelingOrStartingApp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(directory: root)
        let model = AppModel(storage: store)
        let installedChannel = Identity.releaseChannel, installedVersion = Identity.version
        XCTAssertEqual(model.updateChannel, .installedDefault)
        model.selectUpdateChannel(.stable)
        XCTAssertEqual(try store.loadUpdatePreferences().channel, .stable)
        model.shutdown()
        let restored = AppModel(storage: store)
        defer { restored.shutdown() }
        XCTAssertEqual(restored.updateChannel, .stable)
        XCTAssertEqual(Identity.releaseChannel, installedChannel)
        XCTAssertEqual(Identity.version, installedVersion)
        XCTAssertEqual(restored.state, .idle)
        XCTAssertNil(restored.armed)
        XCTAssertNil(restored.planRun)
        restored.selectUpdateChannel(.dev)
        XCTAssertEqual(try store.loadUpdatePreferences().channel, .dev)
    }

    @MainActor func testChannelChangeDoesNotAlterPlaybackScheduleOrUnsavedSettings() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SettingsStore(directory: root)
        let model = AppModel(storage: store)
        defer { model.shutdown(); try? FileManager.default.removeItem(at: root) }
        model.settings.hours = 8.5; model.settings.gainDB = -55
        model.settings.playbackPlan = PlaybackPlan(mode: .split40, sessionMinutes: 180, restMinutes: 30)
        var run = try PlaybackPlanRun(plan: model.settings.selectedPlan, customMinutes: 510, program: .fullCycle)
        run.finishSession(at: Date())
        model.planRun = run; model.armed = run.nextStart
        model.selectedUID = "unchanged-device"
        let settings = model.settings
        // Exercise control states without starting real audio or a scheduler.
        for state in [PlaybackState.idle, .preparing, .playing, .paused, .completed] {
            model.state = state
            for channel in [UpdateChannel.stable, .dev] {
                model.selectUpdateChannel(channel)
                XCTAssertEqual(model.updateChannel, channel)
                XCTAssertEqual(model.state, state)
                XCTAssertEqual(model.settings, settings)
                XCTAssertEqual(model.planRun, run)
                XCTAssertEqual(model.armed, run.nextStart)
                XCTAssertEqual(model.selectedUID, "unchanged-device")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("swift-session-v1.json").path))
    }

    @MainActor func testFailedSaveKeepsPreviousChannelAndReportsError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SettingsStore(directory: root)
        try store.saveUpdatePreferences(UpdatePreferences(channel: .stable))
        let model = AppModel(storage: store)
        defer { model.shutdown(); try? FileManager.default.removeItem(at: root) }
        model.language = "en"; model.error = nil
        let file = root.appendingPathComponent("swift-updates-v1.json")
        try FileManager.default.removeItem(at: file)
        // An existing directory blocks an atomic file replacement on every host.
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        model.selectUpdateChannel(.dev)
        XCTAssertEqual(model.updateChannel, .stable)
        XCTAssertEqual(model.error, "Update channel could not be saved. Your previous choice is unchanged.")
        XCTAssertEqual(model.state, .idle)
    }
}

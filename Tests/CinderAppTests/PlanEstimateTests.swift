import XCTest
import CinderCore
import CinderStorage
@testable import CinderApp

final class PlanEstimateTests: XCTestCase {
    @MainActor func testSplitEstimateIncludesFutureSessionsAndRest() throws {
        let store = SettingsStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let model = AppModel(storage: store)
        defer { model.shutdown(); try? FileManager.default.removeItem(at: store.directory) }
        let plan = PlaybackPlan(mode: .split40, sessionMinutes: 180, restMinutes: 30)
        model.settings.playbackPlan = plan
        model.planRun = try PlaybackPlanRun(plan: plan, customMinutes: 510, program: .fullCycle)
        model.state = .playing
        var snapshot = AudioSnapshot(); snapshot.elapsed = 600; model.snapshot = snapshot
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(model.estimatedPlanEnd(at: now), now.addingTimeInterval(46.5 * 3600 - 600))
        model.planRun?.finishSession(at: now); model.state = .completed; model.snapshot = AudioSnapshot()
        XCTAssertEqual(model.estimatedPlanEnd(at: now), now.addingTimeInterval(43.5 * 3600))
    }
    @MainActor func testNoFinishEstimateWhileIdlePreparingOrPaused() {
        let store = SettingsStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let model = AppModel(storage: store)
        defer { model.shutdown(); try? FileManager.default.removeItem(at: store.directory) }
        for state in [PlaybackState.idle, .preparing, .paused, .failed, .completed] {
            model.state = state
            XCTAssertNil(model.estimatedPlanEnd(at: Date()))
        }
    }
}

import XCTest
import CinderCore

final class PlaybackTimingTests: XCTestCase {
    func testContinuousCycleSeparatesSignalAndRest() throws {
        let timing = try PlaybackTiming(plan: PlaybackPlan(mode: .continuous40), customMinutes: 60, program: .fullCycle)
        XCTAssertEqual(timing.sessionSeconds, 144000)
        XCTAssertEqual(timing.signalSeconds, 120000)
        XCTAssertEqual(timing.cycleRestSeconds, 24000)
        XCTAssertEqual(timing.betweenSessionRestSeconds, 0)
    }
    func testSplitRestAndPartialCyclesRestartPerSession() throws {
        let plan = PlaybackPlan(mode: .split40, sessionMinutes: 90, restMinutes: 30)
        let timing = try PlaybackTiming(plan: plan, customMinutes: 60, program: .fullCycle)
        // 26 × 90-minute sessions (75-minute signal) and one 60-minute session (50).
        XCTAssertEqual(timing.signalSeconds, 120000)
        XCTAssertEqual(timing.betweenSessionRestSeconds, 26 * 1800)
        XCTAssertEqual(timing.totalSeconds, 144000 + 26 * 1800)
        let partial = try PlaybackTiming(plan: PlaybackPlan(mode: .split40, sessionMinutes: 80, restMinutes: 0), customMinutes: 60, program: .fullCycle)
        XCTAssertEqual(partial.signalSeconds, 30 * 65 * 60)
    }
    func testSingleSignalsAndCycleBoundaries() throws {
        for program in [PlaybackProgram.pink, .band, .music, .sweep] {
            let timing = try PlaybackTiming(plan: PlaybackPlan(), customMinutes: 37, program: program)
            XCTAssertEqual(timing.signalSeconds, 37 * 60)
            XCTAssertEqual(timing.cycleRestSeconds, 0)
        }
        XCTAssertEqual(PlaybackTiming.signalTime(elapsed: 900, program: .fullCycle), 900)
        XCTAssertEqual(PlaybackTiming.signalTime(elapsed: 1200, program: .fullCycle), 900)
        XCTAssertEqual(PlaybackTiming.signalTime(elapsed: 3600, program: .fullCycle), 3000)
        XCTAssertEqual(PlaybackTiming.signalTime(elapsed: .nan, program: .fullCycle), 0)
    }
}

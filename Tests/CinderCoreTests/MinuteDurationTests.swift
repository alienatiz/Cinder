import XCTest
import CinderCore
import CinderDSP
import CinderStorage

final class MinuteDurationTests: XCTestCase {
    func testAllSupportedMinuteValuesRoundTripWithoutDrift() throws {
        for minutes in 1...PlaybackDuration.maximumMinutes {
            let hours = try PlaybackDuration.hours(fromMinutes: minutes)
            XCTAssertEqual(try PlaybackDuration.minutes(fromHours: hours), minutes)
        }
        for invalid in [0, -1, 60001] { XCTAssertThrowsError(try PlaybackDuration.hours(fromMinutes: invalid)) }
        for invalid in [Double.nan, .infinity, -1, 0, 0.001, 1000.1] { XCTAssertThrowsError(try PlaybackDuration.minutes(fromHours: invalid)) }
    }
    func testMinuteSessionPersistsAndFullCycleStillNeedsAnHour() throws {
        var settings = SessionSettings()
        settings.hours = try PlaybackDuration.hours(fromMinutes: 67)
        let decoded = try JSONDecoder().decode(SessionSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.durationMinutes, 67)
        XCTAssertEqual(decoded.durationSeconds, 4020)
        settings.hours = try PlaybackDuration.hours(fromMinutes: 1)
        XCTAssertThrowsError(try settings.validatePlayback())
        for program in [PlaybackProgram.pink, .band, .music, .sweep] {
            settings.program = program
            XCTAssertNoThrow(try settings.validatePlayback())
        }
    }
    func testOneMinuteEngineFinishesAtExactFrameCount() throws {
        let kernel = try XCTUnwrap(cinder_create(32000, 1.0 / 60, -30))
        defer { cinder_destroy(kernel) }
        XCTAssertEqual(cinder_program(kernel, 0), 1)
        var left = [Float](repeating: 0, count: 4096), right = left
        for _ in 0..<469 { cinder_render(kernel, &left, &right, 4096) }
        let metrics = cinder_metrics(kernel)
        XCTAssertEqual(metrics.frames, 60 * 32000)
        XCTAssertEqual(metrics.finished, 1)
        cinder_render(kernel, &left, &right, 4096)
        XCTAssertTrue(left.allSatisfy { $0 == 0 })
    }
    func testCompletionRestoresDialWithoutChangingRecordedElapsed() {
        XCTAssertEqual(PlaybackDuration.dialSeconds(configuredSeconds: 4020, elapsed: 4020, state: .completed), 4020)
        XCTAssertEqual(PlaybackDuration.dialSeconds(configuredSeconds: 4020, elapsed: 120, state: .playing), 3900)
        XCTAssertEqual(PlaybackDuration.dialSeconds(configuredSeconds: 4020, elapsed: 120, state: .paused), 3900)
        XCTAssertEqual(PlaybackDuration.dialSeconds(configuredSeconds: 4020, elapsed: 4020, state: .idle), 4020)
    }
}

import XCTest
import CinderCore
import CinderDSP

final class PlaybackProgramTests: XCTestCase {
    func testFullCycleMinimumAndShortPrograms() throws {
        var settings = SessionSettings(); settings.hours = 0.5
        XCTAssertThrowsError(try settings.validatePlayback())
        for program in [PlaybackProgram.pink, .band, .music, .sweep] {
            settings.program = program; XCTAssertNoThrow(try settings.validatePlayback())
        }
        settings.program = .fullCycle; settings.hours = 1
        XCTAssertNoThrow(try settings.validatePlayback())
        XCTAssertEqual(Cycle.seconds.reduce(0, +), 3600)
        let legacy = try JSONDecoder().decode(SessionSettings.self, from: Data("{\"hours\":30,\"gainDB\":-30,\"keepAwake\":true}".utf8))
        XCTAssertEqual(legacy.selectedProgram, .fullCycle)
    }
    func testSingleSweepStartsWithoutEarlierCycleSteps() throws {
        let a = try XCTUnwrap(cinder_create(32000, 0.5, -15))
        let b = try XCTUnwrap(cinder_create(32000, 0.5, -15))
        defer { cinder_destroy(a); cinder_destroy(b) }
        XCTAssertEqual(cinder_program(a, PlaybackProgram.sweep.step), 1)
        XCTAssertEqual(cinder_program(b, 99), 0)
        var left = [Float](repeating: 0, count: 4096), right = left
        var reference = left, referenceRight = left
        cinder_render(a, &left, &right, 4096)
        cinder_render(b, &reference, &referenceRight, 4096)
        XCTAssertNotEqual(left, reference)
        XCTAssertTrue(left.contains { abs($0) > 0 })
        XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) <= 0.50001 })
        XCTAssertEqual(left, right)
        XCTAssertEqual(cinder_program(a, 0), 0)
    }
}

import XCTest
import CinderCore
import CinderDSP
import CinderStorage

final class CoreTests: XCTestCase {
    func testMinuteDurationAndInvalidInput() throws {
        var settings = SessionSettings()
        for hours in [1.0 / 60, 0.25, 0.5, 20, 30.1, 50, 1000] {
            settings.hours = hours; XCTAssertNoThrow(try settings.validate())
        }
        for hours in [0, 0.001, 30.001, 1000.5, .infinity, .nan] {
            settings.hours = hours; XCTAssertThrowsError(try settings.validate())
        }
        settings.hours = 0.5
        XCTAssertEqual(settings.hours * 3600, 1800)
        for gain in [1.0, -61, .nan] {
            settings.gainDB = gain; XCTAssertThrowsError(try settings.validate())
        }
    }
    func testCycleBoundaries() {
        XCTAssertEqual(Cycle.seconds.reduce(0, +), 3600)
        for (time, step) in [(0.0, 0), (899.99, 0), (900, 1), (1200, 2), (2100, 3), (3000, 4), (3300, 5), (3600, 0)] {
            XCTAssertEqual(Cycle.step(at: time), step)
        }
        XCTAssertEqual(Cycle.time(1800), "00:30:00")
        XCTAssertEqual(Cycle.time(108000), "30:00:00")
    }
    func testDeterministicSignalHeadroomAndPause() throws {
        let a = try XCTUnwrap(cinder_create(32000, 0.5, 0))
        let b = try XCTUnwrap(cinder_create(32000, 0.5, 0))
        defer { cinder_destroy(a); cinder_destroy(b) }
        var left = [Float](repeating: 0, count: 2048)
        var right = left, reference = left, referenceRight = left
        for _ in 0..<32 {
            cinder_render(a, &left, &right, 2048)
            cinder_render(b, &reference, &referenceRight, 2048)
            XCTAssertEqual(left, reference)
            XCTAssertEqual(left, right)
            XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) <= 0.50001 })
        }
        XCTAssertGreaterThan(cinder_metrics(a).rms, 0)
        cinder_pause(a, 1)
        for _ in 0..<20 { cinder_render(a, &left, &right, 2048) }
        let paused = cinder_metrics(a)
        XCTAssertEqual(paused.paused, 1)
        cinder_render(a, &left, &right, 2048)
        XCTAssertEqual(cinder_metrics(a).frames, paused.frames)
        XCTAssertTrue(left.allSatisfy { $0 == 0 })
        cinder_pause(a, 0)
        cinder_render(a, &left, &right, 2048)
        XCTAssertGreaterThan(cinder_metrics(a).frames, paused.frames)
        cinder_stop(a)
        for _ in 0..<20 { cinder_render(a, &left, &right, 2048) }
        XCTAssertEqual(cinder_metrics(a).finished, 1)
    }
    func testKernelRejectsInvalidParameters() {
        XCTAssertNil(cinder_create(0, 30, -30))
        XCTAssertNil(cinder_create(48000, 0.001, -30))
        XCTAssertNil(cinder_create(48000, 30, 1))
    }
    func testPeakHoldsUntilReadAndRMSUsesLatest100Milliseconds() throws {
        let kernel = try XCTUnwrap(cinder_create(32000, 0.5, 0))
        defer { cinder_destroy(kernel) }
        var left = [Float](repeating: 0, count: 1024), right = left
        var energy = 0.0, peak: Float = 0
        for block in 0..<64 {
            cinder_render(kernel, &left, &right, 1024)
            for i in left.indices {
                peak = max(peak, max(abs(left[i]), abs(right[i])))
                let frame = block * 1024 + i
                // Latest completed 3200-frame window in 65536 frames.
                if (60800..<64000).contains(frame) {
                    energy += (Double(left[i]) * Double(left[i]) + Double(right[i]) * Double(right[i])) * 0.5
                }
            }
        }
        let value = cinder_metrics(kernel)
        XCTAssertEqual(value.peak, peak, accuracy: 0.000001)
        XCTAssertEqual(Double(value.rms), sqrt(energy / 3200), accuracy: 0.000001)
        let consumed = cinder_metrics(kernel)
        XCTAssertEqual(consumed.peak, 0)
        XCTAssertEqual(consumed.rms, value.rms)
    }
    func testRMSDoesNotDependOnPollingOrPausedSilence() throws {
        let a = try XCTUnwrap(cinder_create(32000, 0.5, -15))
        let b = try XCTUnwrap(cinder_create(32000, 0.5, -15))
        defer { cinder_destroy(a); cinder_destroy(b) }
        var left = [Float](repeating: 0, count: 3200), right = left
        for _ in 0..<20 {
            cinder_render(a, &left, &right, 3200)
            _ = cinder_metrics(a)
            cinder_render(b, &left, &right, 3200)
        }
        XCTAssertEqual(cinder_metrics(a).rms, cinder_metrics(b).rms)
        cinder_pause(a, 1); cinder_pause(b, 1)
        for _ in 0..<10 {
            cinder_render(a, &left, &right, 3200)
            cinder_render(b, &left, &right, 3200)
        }
        XCTAssertEqual(cinder_metrics(a).paused, 1)
        // Only one kernel receives a long interval of paused callbacks.
        for _ in 0..<1000 { cinder_render(b, &left, &right, 3200) }
        cinder_pause(a, 0); cinder_pause(b, 0)
        cinder_render(a, &left, &right, 3200)
        cinder_render(b, &left, &right, 3200)
        XCTAssertEqual(cinder_metrics(a).rms, cinder_metrics(b).rms)
        XCTAssertGreaterThan(cinder_metrics(a).rms, 0)
    }
    func testSettingsRoundTripRejectsInvalidSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(directory: directory)
        var settings = SessionSettings()
        settings.hours = 0.5; settings.gainDB = -15
        try store.save(settings)
        XCTAssertEqual(try store.load(), settings)
        var invalid = settings; invalid.hours = 0.001
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertEqual(try store.load(), settings)
    }
}

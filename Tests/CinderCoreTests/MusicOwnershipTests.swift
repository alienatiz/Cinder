import XCTest
import Darwin
import CinderDSP
@testable import CinderAudio

final class MusicOwnershipTests: XCTestCase {
    func testBufferCapacityIsBoundedBeforeAllocation() {
        XCTAssertThrowsError(try PreparedSamples(capacity: -1))
        XCTAssertThrowsError(try PreparedSamples(capacity: 32_000_001))
    }
    func testPreparedBuffersTransferToRendererWithoutCopying() throws {
        let kernel = try XCTUnwrap(cinder_create(32000, 0.5, 0))
        defer { cinder_destroy(kernel) }
        XCTAssertEqual(cinder_program(kernel, 3), 1)
        do {
            let left = try PreparedSamples(capacity: 3200)
            let right = try PreparedSamples(capacity: 3200)
            for _ in 0..<3200 { left.append(0.25); right.append(0) }
            XCTAssertEqual(cinder_music_take(kernel, left.pointer, right.pointer, UInt32(left.count)), 1)
            left.transferOwnership(); right.transferOwnership()
        }
        var left = [Float](repeating: 0, count: 3200), right = left
        for _ in 0..<20 { cinder_render(kernel, &left, &right, 3200) }
        XCTAssertEqual(left.last!, 0.25, accuracy: 0.0001)
        XCTAssertTrue(right.allSatisfy { $0 == 0 })
    }
    func testInvalidTransferLeavesOwnershipWithCaller() throws {
        let kernel = try XCTUnwrap(cinder_create(32000, 0.5, 0))
        defer { cinder_destroy(kernel) }
        let left = try PreparedSamples(capacity: 1), right = try PreparedSamples(capacity: 1)
        left.append(.nan); right.append(0)
        XCTAssertEqual(cinder_music_take(kernel, left.pointer, right.pointer, 1), 0)
        // Caller buffers remain valid and will be freed on scope exit.
        left[0] = 0.25
        XCTAssertEqual(left[0], 0.25)
    }
}

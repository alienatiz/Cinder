import XCTest
import CinderCore
import CinderDSP

final class GainPolicyTests: XCTestCase {
    func testManualGainBounds() {
        XCTAssertEqual(GainPolicy.initial, -30)
        for value in [-60.0, -30, -15, -1, 0] { XCTAssertNoThrow(try GainPolicy.validate(value)) }
        for value in [-60.1, 0.1, Double.nan, .infinity, -.infinity] { XCTAssertThrowsError(try GainPolicy.validate(value)) }
    }
    func testInvalidLiveGainKeepsSignalUnchanged() throws {
        let actual = try XCTUnwrap(cinder_create(32000, 0.5, -30))
        let reference = try XCTUnwrap(cinder_create(32000, 0.5, -30))
        defer { cinder_destroy(actual); cinder_destroy(reference) }
        var left = [Float](repeating: 0, count: 2048), right = [Float](repeating: 0, count: 2048)
        var expectedLeft = left, expectedRight = right
        for bad in [Double.nan, .infinity, 1, -61] {
            cinder_gain(actual, bad)
            cinder_render(actual, &left, &right, 2048)
            cinder_render(reference, &expectedLeft, &expectedRight, 2048)
            XCTAssertEqual(left, expectedLeft)
            XCTAssertEqual(right, expectedRight)
        }
    }
}

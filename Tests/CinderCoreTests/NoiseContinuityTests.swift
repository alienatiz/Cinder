import XCTest
import CinderDSP

final class NoiseContinuityTests: XCTestCase {
    private func render(rate: Int, program: Int32, seconds: Int, blockSize: Int) throws -> [Float] {
        let kernel = try XCTUnwrap(cinder_create(Double(rate), 1.0 / 60, 0))
        defer { cinder_destroy(kernel) }
        XCTAssertEqual(cinder_program(kernel, program), 1)
        var result = [Float](repeating: 0, count: rate * seconds)
        var right = [Float](repeating: 0, count: blockSize)
        result.withUnsafeMutableBufferPointer { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = min(blockSize, buffer.count - offset)
                cinder_render(kernel, buffer.baseAddress!.advanced(by: offset), &right, UInt32(count))
                offset += count
            }
        }
        return result
    }

    private func rms(_ samples: ArraySlice<Float>) -> Double {
        sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
    }

    func testNoiseDoesNotDipAtRepeatedLoopBoundaries() throws {
        for rate in [32000, 44100, 48000, 192000] {
            for program in [Int32(0), Int32(2)] {
                let samples = try render(rate: rate, program: program, seconds: 25, blockSize: 1021)
                XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 0.50001 })
                let reference = rms(samples[rate..<(rate * 2)])
                XCTAssertGreaterThan(reference, 0)
                for seconds in [12, 24] {
                    let boundary = seconds * rate
                    let halfWindow = Int(Double(rate) * 0.005)
                    let level = rms(samples[(boundary-halfWindow)..<(boundary+halfWindow)]) / reference
                    // Natural noise fluctuates; reject the old >10 dB periodic dropout.
                    XCTAssertGreaterThan(level, 0.5, "rate=\(rate), program=\(program), seam=\(seconds)")
                    XCTAssertLessThan(level, 2.0)
                }
            }
        }
    }

    func testLoopOutputDoesNotDependOnCallbackSize() throws {
        for program in [Int32(0), Int32(2)] {
            let small = try render(rate: 48000, program: program, seconds: 13, blockSize: 127)
            let large = try render(rate: 48000, program: program, seconds: 13, blockSize: 4096)
            XCTAssertEqual(small, large)
        }
    }
}

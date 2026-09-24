import XCTest
import AVFoundation
@testable import CinderAudio

final class MusicTests: XCTestCase {
    func testInspectionReportsFLACFormatAndRejectsDSD() throws {
        let flac = try XCTUnwrap(Bundle.module.url(forResource: "stereo-96k-239s", withExtension: "flac", subdirectory: "Fixtures"))
        let item = try XCTUnwrap(MusicInspection.inspect([flac.path]).first)
        XCTAssertNil(item.issue)
        XCTAssertEqual(item.format, "FLAC")
        XCTAssertEqual(item.bits, 24)
        XCTAssertEqual(item.sampleRate, 96000)
        XCTAssertEqual(item.channels, 2)
        let dsd = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")
        defer { try? FileManager.default.removeItem(at: dsd) }
        try Data("DSD ".utf8).write(to: dsd)
        let unsupported = try XCTUnwrap(MusicInspection.inspect([dsd.path]).first)
        XCTAssertEqual(unsupported.format, "DSD / DSF")
        XCTAssertNotNil(unsupported.issue)
    }
    func testLongFLACDoesNotHitFormerWorkingBufferLimit() throws {
        let files = try [239, 258].map { seconds in
            try XCTUnwrap(Bundle.module.url(forResource: "stereo-96k-\(seconds)s", withExtension: "flac", subdirectory: "Fixtures")).path
        }
        XCTAssertEqual(try MusicLoader.duration(files), 497, accuracy: 0.001)
        let (left, right) = try MusicLoader.prepareOwned(files, rate: 48000)
        XCTAssertEqual(left.count, right.count)
        XCTAssertEqual(Double(left.count) / 48000, 497, accuracy: 0.02)
        XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) <= 0.50001 })
        XCTAssertTrue(right.allSatisfy { $0 == 0 })
        XCTAssertTrue(left.prefix(48000).contains { abs($0) > 0.01 })
        XCTAssertTrue(left.suffix(48000).contains { abs($0) > 0.01 })
        let boundary = 239 * 48000
        XCTAssertTrue(left[(boundary - 24000)..<boundary].contains { abs($0) > 0.01 })
        XCTAssertTrue(left[boundary..<(boundary + 24000)].contains { abs($0) > 0.01 })
    }
    func testRejectsInvalidOutputRateBeforeAllocating() {
        for rate in [0.0, .nan, .infinity, 8000] {
            XCTAssertThrowsError(try MusicLoader.prepareOwned([], rate: rate))
        }
    }
    func testCancelledPreparationDoesNotReadFiles() async {
        let task = Task.detached { () throws -> Void in
            // Synchronize cancellation without timing-sensitive sleeps.
            while !Task.isCancelled { await Task.yield() }
            _ = try MusicLoader.prepareOwned(["/nonexistent/cancelled.wav"], rate: 48000)
        }
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError { }
        catch { XCTFail("Expected cancellation before file access: \(error)") }
    }
    func testCancelledInspectionDoesNotPublishPartialLibrary() async {
        let task = Task.detached {
            while !Task.isCancelled { await Task.yield() }
            return MusicInspection.inspect(["/nonexistent/cancelled.wav"])
        }
        task.cancel()
        let results = await task.value
        XCTAssertTrue(results.isEmpty)
    }
    func testMusicMetadataConversionAndHeadroom() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: file) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100))
        buffer.frameLength = 44100
        let data = try XCTUnwrap(buffer.floatChannelData)
        for i in 0..<44100 { data[0][i] = Float(sin(Double(i) * 2 * .pi * 440 / 44100) * 0.2); data[1][i] = 0 }
        do { let writer = try AVAudioFile(forWriting: file, settings: format.settings); try writer.write(from: buffer) }
        XCTAssertEqual(try MusicLoader.duration([file.path]), 1, accuracy: 0.01)
        let (left, right) = try MusicLoader.prepareOwned([file.path], rate: 48000)
        XCTAssertEqual(left.count, right.count)
        XCTAssertEqual(Double(left.count) / 48000, 1, accuracy: 0.02)
        XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) <= 0.5 })
        XCTAssertTrue(right.allSatisfy { $0 == 0 })
        XCTAssertTrue(left.contains { abs($0) > 0.01 })
    }
}

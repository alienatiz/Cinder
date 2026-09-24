import XCTest
import AVFoundation
@testable import CinderAudio
import CinderCore
import CinderDSP
import CinderStorage

final class PresetMusicTests: XCTestCase {
    func testLegacySettingsAndPresetsKeepLibraryMode() throws {
        let legacy = Data(#"{"hours":30,"gainDB":-30,"keepAwake":true}"#.utf8)
        let settings = try JSONDecoder().decode(SessionSettings.self, from: legacy)
        XCTAssertEqual(settings.selectedMusicSource, .library)
        XCTAssertEqual(settings.selectedMusicPreset, .balanced)
        let document = Data(#"{"schema_version":1,"kind":"cinder_preset","name":"Legacy","settings":{"hours":30,"gain_db":-30,"music":[],"time":"02:00","repeat_days":0,"sessions":1,"keep_awake":true}}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(PresetDocument.self, from: document).settings.selectedMusicSource, .library)
    }
    func testAllSevenChoicesRoundTripAndKeepStableResourceNames() throws {
        XCTAssertEqual(PresetMusic.allCases.map(\.rawValue), ["classic","balanced","electronic","acoustic","pop","rock","metal"])
        for preset in PresetMusic.allCases {
            var settings = SessionSettings()
            settings.program = .music; settings.musicSource = .preset; settings.musicPreset = preset
            settings.hours = 1.0 / 60
            try settings.validatePlayback()
            XCTAssertEqual(try JSONDecoder().decode(SessionSettings.self, from: JSONEncoder().encode(settings)), settings)
            var document = PresetDocument(name: preset.label, settings: .init(hours: 1.0 / 60, gain: -30, music: [], dac: nil, time: "02:00", days: 0, sessions: 1, awake: true))
            document.settings.music_source = .preset; document.settings.music_preset = preset
            document.settings.program = .music
            try document.validate()
            let decoded = try JSONDecoder().decode(PresetDocument.self, from: JSONEncoder().encode(document))
            XCTAssertEqual(decoded.settings.music_preset, preset)
            XCTAssertEqual(decoded.settings.selectedMusicSource, .preset)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(PresetMusic.self, from: Data(#""unknown""#.utf8)))
    }
    func testSavingMusicChoicePreservesSavedGainAndDuration() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SettingsStore(directory: folder)
        var saved = SessionSettings(); saved.hours = 50; saved.gainDB = -21.5; saved.resetGainDB = -21.5
        try store.save(saved)
        try store.saveMusicPreference(source: .preset, preset: .metal)
        let loaded = try store.load()
        XCTAssertEqual(loaded.hours, 50); XCTAssertEqual(loaded.gainDB, -21.5)
        XCTAssertEqual(loaded.resetGainDB, -21.5); XCTAssertEqual(loaded.selectedMusicPreset, .metal)
        try store.saveGainDefault(-35)
        XCTAssertEqual(try store.load().selectedMusicSource, .preset)
        XCTAssertEqual(try store.load().selectedMusicPreset, .metal)
    }
    private func asset(_ preset: PresetMusic) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CinderApp/Resources").appendingPathComponent(preset.filename)
    }
    func testPreparedLoopsPreserveMasterAtNativeRate() throws {
        for preset in PresetMusic.allCases {
            let url = asset(preset)
            let (left, right) = try PresetMusicLoader.prepareOwned(url, rate: 48000, expectedSeconds: preset.loopSeconds)
            XCTAssertEqual(left.count, Int((preset.loopSeconds * 48000).rounded()))
            XCTAssertEqual(left.count, right.count)
            XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) <= 0.50001 })
            XCTAssertTrue(right.allSatisfy { $0.isFinite && abs($0) <= 0.50001 })
            let file = try AVAudioFile(forReading: url)
            let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096))
            try file.read(into: input)
            let channels = try XCTUnwrap(input.floatChannelData)
            for i in 0..<Int(input.frameLength) {
                XCTAssertEqual(left[i], channels[0][i], accuracy: 0.00001)
                XCTAssertEqual(right[i], channels[1][i], accuracy: 0.00001)
            }
        }
    }
    func testPeriodicResamplingIsBoundedAtSupportedRates() throws {
        for rate in [32000.0, 44100, 192000] {
            for preset in [PresetMusic.classic, .metal] {
                let (left, right) = try PresetMusicLoader.prepareOwned(asset(preset), rate: rate, expectedSeconds: preset.loopSeconds)
                XCTAssertEqual(left.count, Int((preset.loopSeconds * rate).rounded()))
                XCTAssertLessThanOrEqual(left.count * 8, 92_160_000)
                XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) <= 0.50001 })
                XCTAssertTrue(right.allSatisfy { $0.isFinite && abs($0) <= 0.50001 })
                XCTAssertLessThan(abs(left[0] - left[left.count-1]), 0.05)
                XCTAssertLessThan(abs(right[0] - right[right.count-1]), 0.05)
            }
        }
    }
    func testPresetLoaderRejectsMissingOrMismatchedAssetsAndCancellation() async throws {
        let url = asset(.classic)
        XCTAssertThrowsError(try PresetMusicLoader.prepareOwned(url, rate: .nan, expectedSeconds: 56))
        XCTAssertThrowsError(try PresetMusicLoader.prepareOwned(url, rate: 48000, expectedSeconds: 60))
        XCTAssertThrowsError(try PresetMusicLoader.prepareOwned(url.appendingPathExtension("missing"), rate: 48000, expectedSeconds: 56))
        let task = Task.detached { () throws -> Void in
            while !Task.isCancelled { await Task.yield() }
            _ = try PresetMusicLoader.prepareOwned(url, rate: 192000, expectedSeconds: 56)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled preparation completed") }
        catch is CancellationError { }
    }
}

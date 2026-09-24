import XCTest
import CinderCore
import CinderStorage

final class GainPresetTests: XCTestCase {
    func testNamedPresetsPersistUpdateAndRemoveWithoutTouchingDefaults() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = GainPresetStore(directory: directory)
        var library = try store.load()
        let first = GainPreset(name: "CHU III · MacBook", gainDB: -21.5, outputUID: "headphones", outputName: "External Headphones")
        try library.upsert(first); try store.save(library)
        XCTAssertEqual(try store.load(), library)
        var replacement = first; replacement.gainDB = -18.25
        try library.upsert(replacement); try store.save(library)
        XCTAssertEqual(try store.load().presets.count, 1)
        XCTAssertEqual(try store.load().presets.first?.gainDB, -18.25)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("swift-session-v1.json").path))
        library.presets.removeAll(); try store.save(library)
        XCTAssertTrue(try store.load().presets.isEmpty)
    }
    func testInvalidGainAndDuplicateNamesDoNotReplaceLibrary() throws {
        var library = GainPresetLibrary()
        try library.upsert(GainPreset(name: "CHU III", gainDB: -30))
        let before = library
        for gain in [1.0, -61, .nan, .infinity] {
            XCTAssertThrowsError(try library.upsert(GainPreset(name: "Other", gainDB: gain)))
            XCTAssertEqual(library, before)
        }
        XCTAssertThrowsError(try library.upsert(GainPreset(name: "chu iii", gainDB: -20)))
        XCTAssertEqual(library, before)
        XCTAssertThrowsError(try library.upsert(GainPreset(name: "   ", gainDB: -20)))
    }
    func testPlaybackPresetsPreserveFractionalGainAndMinuteDuration() throws {
        let legacy = Data(#"{"schema_version":1,"kind":"cinder_preset","name":"Legacy","settings":{"hours":30,"gain_db":-30,"music":[],"time":"02:00","repeat_days":0,"sessions":1,"keep_awake":true}}"#.utf8)
        var preset = try JSONDecoder().decode(PresetDocument.self, from: legacy)
        try preset.validate()
        preset.settings.hours = 67.0 / 60
        preset.settings.gain_db = -18.25
        let restored = try JSONDecoder().decode(PresetDocument.self, from: JSONEncoder().encode(preset))
        try restored.validate()
        XCTAssertEqual(restored.settings.gain_db, -18.25)
        XCTAssertEqual(try PlaybackDuration.minutes(fromHours: restored.settings.hours), 67)
    }
}

import XCTest
import CinderCore
import CinderStorage

final class GainDefaultStorageTests: XCTestCase {
    func testSaveGainPersistsAcrossStoreInstancesWithoutChangingOtherSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(directory: directory)
        var original = SessionSettings()
        original.hours = 2.5
        original.keepAwake = false
        original.resetGainDB = -15
        try store.save(original)
        try store.saveGainDefault(-24)
        let reloaded = try SettingsStore(directory: directory).load()
        XCTAssertEqual(reloaded.gainDB, -24)
        XCTAssertEqual(reloaded.resetGainDB, -24)
        XCTAssertEqual(reloaded.hours, 2.5)
        XCTAssertFalse(reloaded.keepAwake)
        XCTAssertEqual(reloaded.program, original.program)
        XCTAssertThrowsError(try store.saveGainDefault(1))
        XCTAssertEqual(try store.load(), reloaded)
        try store.saveGainDefault(0)
        XCTAssertEqual(try store.load().resetGainDB, 0)
    }
    func testSaveGainWorksBeforeAnySettingsHaveBeenSaved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(directory: directory)
        try store.saveGainDefault(-60)
        let saved = try store.load()
        XCTAssertEqual(saved.resetGainDB, -60)
        XCTAssertEqual(saved.gainDB, -60)
        XCTAssertEqual(saved.hours, 30)
    }
}

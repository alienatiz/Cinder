import XCTest
import CinderCore
import CinderStorage

final class UpdatePreferencesTests: XCTestCase {
    func testExistingSettingsNeedNoMigrationAndChannelWritesStayIndependent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(directory: root)
        var session = SessionSettings()
        session.hours = 8.5; session.gainDB = -42
        let ui = UIPreferences(language: "ko", appearance: "dark", needle: true, outputUID: "saved-device")
        try store.save(session); try store.saveUI(ui)
        let sessionFile = root.appendingPathComponent("swift-session-v1.json")
        let uiFile = root.appendingPathComponent("swift-ui-v1.json")
        let sessionData = try Data(contentsOf: sessionFile), uiData = try Data(contentsOf: uiFile)
        XCTAssertEqual(try store.loadUpdatePreferences().channel, .installedDefault)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("swift-updates-v1.json").path))
        for channel in [UpdateChannel.stable, .dev] {
            try store.saveUpdatePreferences(UpdatePreferences(channel: channel))
            XCTAssertEqual(try store.loadUpdatePreferences().channel, channel)
            XCTAssertEqual(try Data(contentsOf: sessionFile), sessionData)
            XCTAssertEqual(try Data(contentsOf: uiFile), uiData)
        }
        try store.saveUpdatePreferences(UpdatePreferences(channel: .stable))
        try store.saveGainDefault(-30); try store.saveUI(ui)
        XCTAssertEqual(try store.loadUpdatePreferences().channel, .stable)
    }

    func testInvalidChannelFileIsRejectedWithoutOverwritingOtherPreferences() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(directory: root)
        let ui = UIPreferences(language: "ja", appearance: "light", outputUID: "saved-device")
        try store.saveUI(ui)
        let file = root.appendingPathComponent("swift-updates-v1.json")
        let invalid = [Data("{\"channel\":\"unknown\"}".utf8), Data("{}".utf8),
                       Data("invalid".utf8), Data(repeating: 32, count: 65536)]
        for data in invalid {
            try data.write(to: file)
            XCTAssertThrowsError(try store.loadUpdatePreferences())
            XCTAssertEqual(try Data(contentsOf: file), data)
            XCTAssertEqual(try store.loadUI(), ui)
        }
    }
}

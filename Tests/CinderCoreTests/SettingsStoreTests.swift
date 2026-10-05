import XCTest
import CinderCore
import CinderStorage

final class SettingsStoreTests: XCTestCase {
    func testPreferenceUpdatesPreserveOtherFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("nested/preferences")
        let store = SettingsStore(directory: directory)
        var session = SessionSettings()
        session.hours = 2.5; session.gainDB = -42
        let ui = UIPreferences(language: "ja", appearance: "dark", needle: true, outputUID: "saved-output")
        try store.save(SessionSettings())
        try store.saveUI(UIPreferences())
        try store.saveNotificationPreferences(NotificationPreferences(enabled: false))
        try store.saveUpdatePreferences(UpdatePreferences(channel: .dev))

        let updates: [(filename: String, save: () throws -> Void)] = [
            ("swift-session-v1.json", { try store.save(session) }),
            ("swift-ui-v1.json", { try store.saveUI(ui) }),
            ("swift-notifications-v1.json", { try store.saveNotificationPreferences(NotificationPreferences(enabled: true)) }),
            ("swift-updates-v1.json", { try store.saveUpdatePreferences(UpdatePreferences(channel: .stable)) })
        ]
        for update in updates {
            let unchanged = try updates.filter { $0.filename != update.filename }.map {
                let file = directory.appendingPathComponent($0.filename)
                return (file, try Data(contentsOf: file))
            }
            try update.save()
            for (file, previous) in unchanged {
                XCTAssertEqual(try Data(contentsOf: file), previous, file.lastPathComponent)
            }
        }

        let reloaded = SettingsStore(directory: directory)
        XCTAssertEqual(try reloaded.load(), session)
        XCTAssertEqual(try reloaded.loadUI(), ui)
        XCTAssertTrue(try reloaded.loadNotificationPreferences().enabled)
        XCTAssertEqual(try reloaded.loadUpdatePreferences().channel, .stable)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)),
                       Set(updates.map(\.filename)))
    }

    func testInvalidSettingsDoNotCreateOrReplaceFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(directory: directory)
        var invalidSession = SessionSettings(); invalidSession.gainDB = 1
        let invalidUI = UIPreferences(language: "invalid")
        XCTAssertThrowsError(try store.save(invalidSession))
        XCTAssertThrowsError(try store.saveUI(invalidUI))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))

        try store.save(SessionSettings()); try store.saveUI(UIPreferences())
        let sessionFile = directory.appendingPathComponent("swift-session-v1.json")
        let uiFile = directory.appendingPathComponent("swift-ui-v1.json")
        let sessionData = try Data(contentsOf: sessionFile), uiData = try Data(contentsOf: uiFile)
        XCTAssertThrowsError(try store.save(invalidSession))
        XCTAssertThrowsError(try store.saveUI(invalidUI))
        XCTAssertEqual(try Data(contentsOf: sessionFile), sessionData)
        XCTAssertEqual(try Data(contentsOf: uiFile), uiData)
    }

    func testSaveFailuresLeaveBlockingFileUntouched() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("preferences")
        let existing = Data("Existing file, not a preferences directory.".utf8)
        try existing.write(to: file)
        let store = SettingsStore(directory: file)
        XCTAssertThrowsError(try store.save(SessionSettings()))
        XCTAssertThrowsError(try store.saveUI(UIPreferences()))
        XCTAssertThrowsError(try store.saveNotificationPreferences(NotificationPreferences()))
        XCTAssertThrowsError(try store.saveUpdatePreferences(UpdatePreferences()))
        XCTAssertEqual(try Data(contentsOf: file), existing)
    }
}

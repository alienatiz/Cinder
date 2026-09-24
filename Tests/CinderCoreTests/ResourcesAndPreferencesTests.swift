import XCTest
import CinderCore
import CinderStorage

final class ResourcesAndPreferencesTests: XCTestCase {
    func testResourceLayoutsAndFailureReporting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let data = Data("{\"Start\":\"시작\"}".utf8)
        let file = nested.appendingPathComponent("lang_ko.json")
        try data.write(to: file)
        let reader = ResourceFiles(root: root)
        XCTAssertEqual(try reader.decode([String: String].self, filename: "lang_ko.json")["Start"], "시작")
        try FileManager.default.moveItem(at: file, to: root.appendingPathComponent("lang_ko.json"))
        XCTAssertEqual(try reader.decode([String: String].self, filename: "lang_ko.json")["Start"], "시작")
        XCTAssertThrowsError(try reader.decode(Changelog.self, filename: "changelog.json"))
        try Data("invalid".utf8).write(to: root.appendingPathComponent("lang_ko.json"))
        XCTAssertThrowsError(try reader.decode([String: String].self, filename: "lang_ko.json"))
    }
    func testUIPreferencesRoundTripAndInvalidSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(directory: root)
        XCTAssertNil(try store.loadUI())
        let ui = UIPreferences(language: "ja", appearance: "dark", needle: true, outputUID: "test-device")
        try store.saveUI(ui)
        XCTAssertEqual(try store.loadUI(), ui)
        var invalid = ui; invalid.language = "jp"
        XCTAssertThrowsError(try store.saveUI(invalid))
        XCTAssertEqual(try store.loadUI(), ui)
        XCTAssertEqual(try store.load(), SessionSettings())
    }
    func testSourceResourcesDecodeWithAppModels() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CinderApp/Resources")
        let reader = ResourceFiles(root: root)
        let history = try reader.decode(Changelog.self, filename: "changelog.json")
        XCTAssertEqual(history.releases.first?.version, Identity.version)
        XCTAssertFalse(history.releases.isEmpty)
        let english = try reader.decode([String: String].self, filename: "lang_en.json")
        for name in ["lang_ko.json", "lang_jp.json"] {
            let language = try reader.decode([String: String].self, filename: name)
            XCTAssertEqual(Set(language.keys), Set(english.keys))
        }
    }
}

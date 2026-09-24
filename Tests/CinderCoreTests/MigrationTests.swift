import XCTest
import CinderCore
import CinderStorage

final class MigrationTests: XCTestCase {
    private var resources: ResourceFiles {
        ResourceFiles(root: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/CinderApp/Resources"))
    }
    func testLegacyPresetJSONAndYAMLRoundTrip() throws {
        let preset = try resources.decode(PresetDocument.self, filename: "30-min.json")
        try preset.validate(); XCTAssertEqual(preset.settings.hours, 0.5)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for ext in ["json", "yaml"] {
            let file = root.appendingPathComponent("preset." + ext)
            try Documents.write(preset, to: file)
            let restored = try Documents.read(PresetDocument.self, at: file)
            try restored.validate(); XCTAssertEqual(restored.settings.hours, 0.5)
        }
        var invalid = preset; invalid.settings.repeat_days = -1
        XCTAssertThrowsError(try invalid.validate())
    }
    func testThemeValidation() throws {
        var theme = try resources.decode(ThemeDocument.self, filename: "cinder-dark.json")
        XCTAssertNoThrow(try theme.validate())
        theme.colors["accent"] = "red"
        XCTAssertThrowsError(try theme.validate())
        XCTAssertFalse(ThemeDocument.validHex("#12345"))
    }
    func testScheduleGraceAndOverlap() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 2))!
        XCTAssertEqual(ScheduleRules.due(target: anchor, now: anchor.addingTimeInterval(-1)), "waiting")
        XCTAssertEqual(ScheduleRules.due(target: anchor, now: anchor.addingTimeInterval(60)), "due")
        XCTAssertEqual(ScheduleRules.due(target: anchor, now: anchor.addingTimeInterval(61)), "missed")
        let after = anchor.addingTimeInterval(30 * 3600)
        let next = try ScheduleRules.next(anchor: anchor, days: 1, after: after, calendar: calendar)
        XCTAssertEqual(next, anchor.addingTimeInterval(48 * 3600))
        XCTAssertThrowsError(try ScheduleRules.next(anchor: anchor, days: 0, after: after))
    }
    func testScheduleSkipsDSTGap() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 2, minute: 30))!
        let next = try ScheduleRules.next(anchor: anchor, days: 1, after: anchor, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: next), 2)
        XCTAssertEqual(calendar.component(.day, from: next), 9)
    }
    func testProfileData() throws {
        let macs = try resources.decode([MacProfile].self, filename: "mac-profiles.json")
        let dacs = try resources.decode([DACProfile].self, filename: "dac-profiles.json")
        XCTAssertTrue(macs.contains { $0.identifiers.contains("Mac14,9") })
        XCTAssertEqual(dacs.count, 3)
        XCTAssertTrue(dacs.allSatisfy { $0.gain <= -24 })
    }
}

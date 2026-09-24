import XCTest
import CinderCore
import CinderStorage

final class SchedulingPresetTests: XCTestCase {
    func testTimeResolutionAndValidation() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 3))!
        var preset = SchedulingPreset(name: "Night", time: "02:00", repeatDays: 1, sessions: 3)
        let next = try preset.nextDate(after: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: next), 8)
        XCTAssertEqual(calendar.component(.hour, from: next), 2)
        preset.time = "25:00"; XCTAssertThrowsError(try preset.validate())
        preset.time = "02:00"; preset.repeat_days = 0; XCTAssertThrowsError(try preset.validate())
        preset.sessions = 1; XCTAssertNoThrow(try preset.validate())
        preset.kind = "cinder_preset"; XCTAssertThrowsError(try preset.validate())
    }
    func testJSONAndYAMLRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let preset = SchedulingPreset(name: "새벽", time: "02:00", repeatDays: 2, sessions: 5)
        for ext in ["json", "yaml"] {
            let file = root.appendingPathComponent("schedule." + ext)
            try Documents.write(preset, to: file)
            let restored = try Documents.read(SchedulingPreset.self, at: file)
            try restored.validate()
            XCTAssertEqual(restored.name, preset.name)
            XCTAssertEqual(restored.repeat_days, 2)
            XCTAssertEqual(restored.sessions, 5)
        }
    }
}

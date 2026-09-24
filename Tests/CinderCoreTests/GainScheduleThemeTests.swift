import XCTest
@testable import CinderCore

final class GainScheduleThemeTests: XCTestCase {
    func testLegacySettingsKeepUnityResetAndInitialGain() throws {
        let legacy = Data(#"{"hours":30,"gainDB":-30,"keepAwake":true}"#.utf8)
        let settings = try JSONDecoder().decode(SessionSettings.self, from: legacy)
        try settings.validate()
        XCTAssertNil(settings.resetGainDB)
        XCTAssertEqual(settings.gainDB, -30)
        var saved = settings
        saved.resetGainDB = -15
        saved.gainDB = -23
        let restored = try JSONDecoder().decode(SessionSettings.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(restored.resetGainDB, -15)
        XCTAssertEqual(restored.gainDB, -23)
        saved.resetGainDB = 1
        XCTAssertThrowsError(try saved.validate())
        saved.resetGainDB = .nan
        XCTAssertThrowsError(try saved.validate())
    }
    func testTomorrowKeepsClockAcrossYearAndDSTBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        for (year, month, day) in [(2026, 12, 31), (2026, 3, 7), (2026, 10, 31)] {
            let now = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 13, minute: 47, second: 29))!
            let target = ScheduleRules.tomorrow(at: now, calendar: calendar)
            XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: target)).day, 1)
            XCTAssertEqual(calendar.component(.hour, from: target), 13)
            XCTAssertEqual(calendar.component(.minute, from: target), 47)
            XCTAssertEqual(calendar.component(.second, from: target), 0)
        }
        let missingTime = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 2, minute: 30))!
        let target = ScheduleRules.tomorrow(at: missingTime, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: target), 8)
        XCTAssertEqual(calendar.component(.hour, from: target), 3)
    }
    func testThemeAppearanceUsesBackgroundNotThemeName() {
        var theme = ThemeDocument(schema_version: 1, kind: "cinder_theme", id: "custom", name: "Dark in name only", colors: ["window.background": "#FFFFFF"])
        XCTAssertFalse(theme.prefersDark)
        theme.colors["window.background"] = "#17212B"
        XCTAssertTrue(theme.prefersDark)
    }
}

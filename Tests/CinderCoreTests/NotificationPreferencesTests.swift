import XCTest
import CinderCore
import CinderStorage
import CinderPlatform

final class NotificationPreferencesTests: XCTestCase {
    func testDefaultOffAndIndependentPreferencePersistence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(directory: root)
        XCTAssertFalse(try store.loadNotificationPreferences().enabled)
        try store.save(SessionSettings())
        let previous = try Data(contentsOf: root.appendingPathComponent("swift-session-v1.json"))
        try store.saveNotificationPreferences(NotificationPreferences(enabled: true))
        XCTAssertTrue(try store.loadNotificationPreferences().enabled)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("swift-session-v1.json")), previous)
    }
    @MainActor func testCommandLineHostDoesNotRequestSystemPermission() async throws {
        let service = SessionNotifications()
        let permission = await service.permission()
        XCTAssertEqual(permission, .unavailable)
        let allowed = try await service.requestPermission()
        XCTAssertFalse(allowed)
    }
}

import Foundation
import CinderCore

extension SettingsStore {
    public func loadNotificationPreferences() throws -> NotificationPreferences {
        let file = directory.appendingPathComponent("swift-notifications-v1.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return NotificationPreferences() }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 4096 else {
            throw CinderError.audio("Invalid notification preferences.")
        }
        return try JSONDecoder().decode(NotificationPreferences.self, from: Data(contentsOf: file))
    }
    public func saveNotificationPreferences(_ preferences: NotificationPreferences) throws {
        try writeJSON(preferences, filename: "swift-notifications-v1.json")
    }
}

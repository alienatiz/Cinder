import Foundation
import CinderCore

extension SettingsStore {
    /// A separate file keeps older builds and feature reverts compatible with UI/session settings.
    public func loadUpdatePreferences() throws -> UpdatePreferences {
        let file = directory.appendingPathComponent("swift-updates-v1.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return UpdatePreferences() }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 65536 else {
            throw CinderError.audio("Update preferences file is too large.")
        }
        return try JSONDecoder().decode(UpdatePreferences.self, from: Data(contentsOf: file))
    }

    public func saveUpdatePreferences(_ preferences: UpdatePreferences) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(preferences).write(
            to: directory.appendingPathComponent("swift-updates-v1.json"), options: .atomic)
    }
}

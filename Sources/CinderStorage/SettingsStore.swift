import Foundation
import CinderCore

public struct SettingsStore {
    public let directory: URL
    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Identity.settingsDirectory, isDirectory: true)
    }
    public func load() throws -> SessionSettings {
        let file = directory.appendingPathComponent("swift-session-v1.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return SessionSettings() }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 65536 else {
            throw CinderError.audio("Settings file is too large.")
        }
        let settings = try JSONDecoder().decode(SessionSettings.self, from: Data(contentsOf: file))
        try settings.validate(); return settings
    }
    public func save(_ settings: SessionSettings) throws {
        try settings.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: directory.appendingPathComponent("swift-session-v1.json"), options: .atomic)
    }
    /// Save only the gain preference; do not commit unrelated live playback edits.
    public func saveGainDefault(_ gain: Double) throws {
        try GainPolicy.validate(gain)
        var saved = try load()
        saved.gainDB = gain
        saved.resetGainDB = gain
        try save(saved)
    }
    /// Music selection is automatic; preserve unrelated unsaved session edits.
    public func saveMusicPreference(source: MusicSource, preset: PresetMusic) throws {
        var saved = try load()
        saved.musicSource = source; saved.musicPreset = preset
        try save(saved)
    }
    public func loadUI() throws -> UIPreferences? {
        let file = directory.appendingPathComponent("swift-ui-v1.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 65536 else {
            throw CinderError.audio("UI preferences file is too large.")
        }
        let value = try JSONDecoder().decode(UIPreferences.self, from: Data(contentsOf: file))
        try value.validate(); return value
    }
    public func saveUI(_ value: UIPreferences) throws {
        try value.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent("swift-ui-v1.json"), options: .atomic)
    }
}

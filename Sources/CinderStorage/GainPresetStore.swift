import Foundation
import CinderCore

public struct GainPresetStore {
    private let file: URL
    public init(directory: URL) { file = directory.appendingPathComponent("swift-gain-presets-v1.json") }
    public func load() throws -> GainPresetLibrary {
        guard FileManager.default.fileExists(atPath: file.path) else { return GainPresetLibrary() }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 512_000 else {
            throw CinderError.audio("Gain preset library exceeds 512 KB.")
        }
        let value = try JSONDecoder().decode(GainPresetLibrary.self, from: Data(contentsOf: file))
        try value.validate(); return value
    }
    public func save(_ value: GainPresetLibrary) throws {
        try value.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        guard data.count <= 512_000 else { throw CinderError.audio("Gain preset library exceeds 512 KB.") }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }
}

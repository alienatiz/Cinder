import Foundation

public struct GainPreset: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var gainDB: Double
    public var outputUID: String?
    public var outputName: String?
    public init(id: String = UUID().uuidString, name: String, gainDB: Double, outputUID: String? = nil, outputName: String? = nil) {
        self.id = id; self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.gainDB = gainDB; self.outputUID = outputUID; self.outputName = outputName
    }
    public func validate() throws {
        try GainPolicy.validate(gainDB)
        guard UUID(uuidString: id) != nil, (1...80).contains(name.count),
              name == name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              (outputUID?.utf8.count ?? 0) <= 4096, (outputName?.utf8.count ?? 0) <= 1024 else {
            throw CinderError.audio("Enter a gain preset name of 1–80 characters.")
        }
    }
}

public struct GainPresetLibrary: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var presets: [GainPreset] = []
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1, presets.count <= 100, Set(presets.map(\.id)).count == presets.count else {
            throw CinderError.audio("Invalid gain preset library or more than 100 presets.")
        }
        for preset in presets { try preset.validate() }
        let names = presets.map { $0.name.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX")) }
        guard Set(names).count == names.count else { throw CinderError.audio("This name is already used. Choose another name or update the selected preset.") }
    }
    public mutating func upsert(_ preset: GainPreset) throws {
        var candidate = self
        if let index = candidate.presets.firstIndex(where: { $0.id == preset.id }) { candidate.presets[index] = preset }
        else { candidate.presets.append(preset) }
        try candidate.validate()
        self = candidate
    }
}

import Foundation

public struct DACProfile: Codable, Identifiable {
    public let id: String
    public let name: String
    public let manufacturer: String
    public let gain: Double
    public let specification: String
    public let source: String
}
public struct MacProfile: Codable {
    public let identifiers: [String]
    public let name: String
    public let output: String
    public let source: String
}
public struct ConnectedOutput: Codable {
    public let schema_version: Int
    public let name: String
    public let uid: String
    public let sampleRate: Double
    public let mac: String
    public let profile: DACProfile?
    public let actualSPL: String
    public let analogVoltage: String
    public init(name: String, uid: String, rate: Double, mac: String, profile: DACProfile?) {
        schema_version = 1; self.name = name; self.uid = uid; sampleRate = rate; self.mac = mac; self.profile = profile
        actualSPL = "unknown: not measured"; analogVoltage = "unknown: not measured"
    }
}

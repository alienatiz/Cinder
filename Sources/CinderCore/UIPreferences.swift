import Foundation

public struct UIPreferences: Codable, Equatable {
    public var language: String
    public var appearance: String
    public var needle: Bool
    public var outputUID: String
    public init(language: String = "en", appearance: String = "system", needle: Bool = false, outputUID: String = "") {
        self.language = language; self.appearance = appearance
        self.needle = needle; self.outputUID = outputUID
    }
    public func validate() throws {
        guard ["en", "ko", "ja"].contains(language), ["system", "light", "dark"].contains(appearance), outputUID.utf8.count <= 4096 else {
            throw CinderError.audio("Invalid UI preferences.")
        }
    }
}

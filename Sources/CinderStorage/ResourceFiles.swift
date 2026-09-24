import Foundation
import CinderCore

public struct ResourceFiles {
    public let root: URL
    public init(root: URL) { self.root = root }
    public func decode<T: Decodable>(_ type: T.Type, filename: String) throws -> T {
        let file = try url(filename: filename)
        do { return try JSONDecoder().decode(type, from: Data(contentsOf: file)) }
        catch { throw CinderError.audio("Cannot read \(filename): \(error.localizedDescription)") }
    }
    public func url(filename: String) throws -> URL {
        // Accept processed resources and the older copied Resources directory.
        let candidates = [root.appendingPathComponent(filename),
                          root.appendingPathComponent("Resources").appendingPathComponent(filename)]
        guard let file = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CinderError.audio("Missing bundled resource: \(filename)")
        }
        return file
    }
}

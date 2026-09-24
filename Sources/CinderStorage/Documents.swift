import Foundation
import CinderCore
import Yams

public enum Documents {
    public static func read<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 2_000_000 else { throw CinderError.audio("File exceeds 2 MB.") }
        let data = try Data(contentsOf: url)
        if ["yaml", "yml"].contains(url.pathExtension.lowercased()) { return try YAMLDecoder().decode(type, from: data) }
        return try JSONDecoder().decode(type, from: data)
    }
    public static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if ["yaml", "yml"].contains(url.pathExtension.lowercased()) {
            try YAMLEncoder().encode(value).write(to: url, atomically: true, encoding: .utf8)
        } else { try encoder.encode(value).write(to: url, options: .atomic) }
    }
}

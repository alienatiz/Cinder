import Foundation
import CinderCore

public struct SessionHistoryStore: Sendable {
    public let file: URL
    public init(directory: URL) { file = directory.appendingPathComponent("swift-history-v1.json") }
    public func load() throws -> SessionHistory {
        guard FileManager.default.fileExists(atPath: file.path) else { return SessionHistory() }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 4_000_000 else {
            throw CinderError.audio("Session history exceeds 4 MB.")
        }
        let result = try JSONDecoder().decode(SessionHistory.self, from: Data(contentsOf: file))
        try result.validate(); return result
    }
    public func save(_ history: SessionHistory) throws {
        try history.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(history)
        guard data.count <= 4_000_000 else { throw CinderError.audio("Session history exceeds 4 MB.") }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }
}

/// FIFO writes and an explicit shutdown flush; no disk work runs in audio callbacks.
public final class SessionHistoryWriter: Sendable {
    private let store: SessionHistoryStore
    private let queue = DispatchQueue(label: "local.chu.cinder.history", qos: .utility)
    public init(directory: URL) { store = SessionHistoryStore(directory: directory) }
    public func save(_ history: SessionHistory, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [store] in
            do { try store.save(history); completion(true) }
            catch { completion(false) }
        }
    }
    public func flush() { queue.sync {} }
}

import Foundation

public struct MusicPlaylist: Codable, Equatable {
    public var paths: [String]
    public var selected: Set<String>
    public var playbackPaths: [String] { paths.filter { selected.contains($0) } }
    public init(paths: [String], selected: Set<String>) {
        var seen = Set<String>()
        self.paths = paths.filter { seen.insert($0).inserted }
        self.selected = selected.intersection(Set(self.paths))
    }
    public func validate() throws {
        guard paths.count <= 100, Set(paths).count == paths.count,
              selected.isSubset(of: Set(paths)), paths.allSatisfy({ !$0.isEmpty && $0.utf8.count < 4096 }) else {
            throw CinderError.audio("Invalid music library.")
        }
    }
}

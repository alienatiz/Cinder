import XCTest
import CinderCore

final class MusicPlaylistTests: XCTestCase {
    func testOnlySelectedTracksPlayInLibraryOrder() throws {
        let list = MusicPlaylist(paths: ["a.flac", "b.flac", "c.flac"], selected: ["c.flac", "a.flac"])
        XCTAssertEqual(list.playbackPaths, ["a.flac", "c.flac"])
        try list.validate()
        let restored = try JSONDecoder().decode(MusicPlaylist.self, from: JSONEncoder().encode(list))
        XCTAssertEqual(restored, list)
    }
    func testNewLibraryDoesNotSelectTracksAndRemovesDuplicates() {
        XCTAssertEqual(MusicPlaylist(paths: ["a", "b"], selected: []).playbackPaths, [])
        let list = MusicPlaylist(paths: ["a", "a", "b"], selected: ["a", "missing"])
        XCTAssertEqual(list.paths, ["a", "b"])
        XCTAssertEqual(list.playbackPaths, ["a"])
    }
    func testInvalidSavedSelectionIsRejected() throws {
        var list = MusicPlaylist(paths: ["a"], selected: ["a"])
        list.selected.insert("missing")
        XCTAssertThrowsError(try list.validate())
        XCTAssertThrowsError(try MusicPlaylist(paths: (0...100).map(String.init), selected: []).validate())
    }
}

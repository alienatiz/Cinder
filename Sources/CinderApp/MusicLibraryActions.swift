import Foundation
import CinderCore
import CinderStorage

extension AppModel {
    func selectMusicSource(_ source: MusicSource) {
        guard !isLocked else { return }
        settings.musicSource = source
        resetProgressForConfiguration(); saveMusicPreference()
    }
    func selectPresetMusic(_ preset: PresetMusic) {
        guard !isLocked else { return }
        settings.musicPreset = preset
        resetProgressForConfiguration(); saveMusicPreference()
    }
    func useMusicProgram() {
        guard !isLocked else { return }
        settings.program = .music; resetProgressForConfiguration(); tab = 0
    }
    func saveMusicPreference() {
        do { try storage.saveMusicPreference(source: settings.selectedMusicSource, preset: settings.selectedMusicPreset) }
        catch { self.error = t(error.localizedDescription) }
    }
    var musicSummary: String {
        if settings.selectedMusicSource == .preset {
            return t("Preset Music") + " · " + settings.selectedMusicPreset.label
        }
        if playbackMusic.isEmpty {
            return t(settings.selectedProgram == .music ? "Choose tracks or Preset Music in Music." : "No tracks selected: step 4 uses pink noise.")
        }
        return t("Burn-in playlist") + " · \(playbackMusic.count) · " + Cycle.time(musicSeconds)
    }
    func selectMusic(_ path: String, included: Bool) {
        guard !isLocked, music.contains(path) else { return }
        if included {
            guard musicInspection.contains(where: { $0.path == path && $0.issue == nil }) else { return }
            selectedMusic.insert(path)
        } else { selectedMusic.remove(path) }
        saveMusicLibrary()
    }
    func selectPlayableMusic() {
        guard !isLocked else { return }
        selectedMusic = Set(musicInspection.filter { $0.issue == nil }.map(\.path))
        saveMusicLibrary()
    }
    func moveMusic(_ path: String, offset: Int) {
        guard !isLocked, let index = playbackMusic.firstIndex(of: path) else { return }
        let target = index + offset
        guard playbackMusic.indices.contains(target), let a = music.firstIndex(of: path),
              let b = music.firstIndex(of: playbackMusic[target]) else { return }
        music.swapAt(a, b)
        musicInspection.sort { music.firstIndex(of: $0.path)! < music.firstIndex(of: $1.path)! }
        saveMusicLibrary()
    }
    func saveMusicLibrary() {
        do {
            let value = MusicPlaylist(paths: music, selected: selectedMusic)
            try value.validate()
            try Documents.write(value, to: storage.directory.appendingPathComponent("swift-music-library-v1.json"))
        } catch { self.error = error.localizedDescription }
    }
    func restoreMusicLibrary() {
        let url = storage.directory.appendingPathComponent("swift-music-library-v1.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let value = try Documents.read(MusicPlaylist.self, at: url)
            try value.validate()
            replaceMusic(value.paths, selection: value.selected)
        } catch { self.error = error.localizedDescription }
    }
}

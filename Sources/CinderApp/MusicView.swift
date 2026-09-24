import SwiftUI
import CinderCore

struct MusicView: View {
    @ObservedObject var model: AppModel
    @State private var playlistPage = 0
    private var playlistPages: Int { max(1, (model.playbackMusic.count + 4) / 5) }
    var body: some View {
        VStack(spacing: 12) {
            Panel(title: model.t("Music source"), compact: true) {
                Picker(model.t("Music source"), selection: Binding(get: { model.settings.selectedMusicSource }, set: { model.selectMusicSource($0) })) {
                    ForEach(MusicSource.allCases, id: \.self) { source in Text(model.t(source.label)).tag(source) }
                }.pickerStyle(.segmented).disabled(model.isLocked)
            }
            if model.settings.selectedMusicSource == .preset { PresetMusicView(model: model) }
            else { library }
        }
    }
    private var library: some View {
        HStack(alignment: .top, spacing: 20) {
            Panel(title: model.t("Music library"), compact: true) {
                HStack {
                    Button(model.t("Add music…"), action: model.chooseMusic)
                    Button(model.t("Clear")) { model.replaceMusic([]) }
                    Spacer()
                    Text("\(model.music.count) / 100")
                }.disabled(model.isLocked)
                Text(model.t("Check the tracks to use for burn-in. New files start unchecked."))
                if model.libraryBusy { ProgressView(model.t("Checking music…")) }
                MusicFileList(model: model)
                if model.music.isEmpty { Text(model.t("Add music to build your library.")) }
            }
            Panel(title: model.t("Burn-in playlist"), compact: true) {
                Text("\(model.playbackMusic.count) · \(Cycle.time(model.musicSeconds))").font(.title3).monospacedDigit()
                HStack {
                    Button(model.t("Select playable")) { model.selectPlayableMusic() }
                    Button(model.t("Deselect all")) { model.selectedMusic = []; model.saveMusicLibrary() }
                }.disabled(model.isLocked)
                VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(model.playbackMusic.enumerated()).dropFirst(min(playlistPage, playlistPages - 1) * 5).prefix(5), id: \.offset) { index, path in
                            HStack {
                                Text("\(index + 1). " + URL(fileURLWithPath: path).lastPathComponent).lineLimit(2)
                                Spacer()
                                Button { model.moveMusic(path, offset: -1) } label: { Image(systemName: "arrow.up").accessibilityLabel(model.t("Move up")) }.disabled(model.isLocked || index == 0)
                                Button { model.moveMusic(path, offset: 1) } label: { Image(systemName: "arrow.down").accessibilityLabel(model.t("Move down")) }.disabled(model.isLocked || index == model.playbackMusic.count - 1)
                            }
                        }
                }.frame(height: 160, alignment: .top)
                PageControls(model: model, page: $playlistPage, count: playlistPages)
                    .onChange(of: playlistPages) { _, count in playlistPage = min(playlistPage, count - 1) }
                Text(model.t("Selected tracks play in this order and repeat during cycle step 4."))
                if model.playbackMusic.isEmpty { Text(model.t("No tracks selected: step 4 uses pink noise.")) }
                if let issue = model.musicProblem { Text(issue).foregroundStyle(.orange) }
                HStack(spacing: 4) {
                    Text(model.t("Selected music: up to 10 minutes · mono or stereo"))
                    InfoHint(text: model.t("Music supports local files readable by macOS: mono or stereo, 8–96 kHz, up to 10 minutes selected.") + "\n" + model.t("Limits apply to selected tracks only: 10 minutes and 256 MB decoded PCM.") + "\n" + model.t("Library and selection are saved automatically. Files stay in their original locations."))
                }
                Text(model.t("External music is band-limited and faded for this playback path; it is not unprocessed listening playback.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PresetMusicView: View {
    @ObservedObject var model: AppModel
    private var preset: PresetMusic { model.settings.selectedMusicPreset }
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Panel(title: model.t("Preset Music")) {
                HStack(spacing: 4) {
                    Text(model.t("Synthesized instrumental music")).foregroundStyle(.secondary)
                    InfoHint(text: model.t("Preset music help"))
                }
                Picker(model.t("Genre"), selection: Binding(get: { model.settings.selectedMusicPreset }, set: { model.selectPresetMusic($0) })) {
                    ForEach(PresetMusic.allCases) { item in Text(item.label).tag(item) }
                }.pickerStyle(.radioGroup).disabled(model.isLocked)
                Text(model.t(preset.descriptionKey)).fixedSize(horizontal: false, vertical: true)
                Text(String(format: model.t("%d bars · %d BPM · %.1f s loop"), preset.bars, preset.bpm, preset.loopSeconds))
                    .foregroundStyle(.secondary).monospacedDigit()
                if preset == .classic { Text(model.t("Classic band plan")).font(.caption).foregroundStyle(.secondary) }
            }
            Panel(title: model.t("Playback")) {
                Text(preset.label).font(.title2)
                Text(model.t("Action") + " · " + model.t(model.settings.selectedProgram.label))
                Text(model.t("Playback duration") + " · " + Cycle.time(model.settings.durationSeconds)).monospacedDigit()
                Text(model.t("The selected arrangement repeats until the configured session ends."))
                Text(model.t("Music mode plays the preset alone. Full cycle uses it during the music step."))
                Button(model.t("Use Music mode in Quick Play"), action: model.useMusicProgram).disabled(model.isLocked)
                Text(model.t("No audio files or downloads needed. Your music-source and preset choices are saved automatically."))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

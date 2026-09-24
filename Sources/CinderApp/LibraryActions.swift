import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CinderCore
import CinderStorage
import CinderAudio
import CinderPlatform
import CryptoKit

struct ThemeState: Codable { var choice: String; var theme: ThemeDocument?; var audiophile: Bool }

extension AppModel {
    func openJSON(yaml: Bool = false) -> URL? {
        let panel = NSOpenPanel(); panel.allowedContentTypes = yaml ? [.json, UTType(filenameExtension: "yaml") ?? .text, UTType(filenameExtension: "yml") ?? .text] : [.json]; panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
    func saveJSON(_ filename: String, yaml: Bool = false) -> URL? {
        let panel = NSSavePanel(); panel.allowedContentTypes = yaml ? [.json, UTType(filenameExtension: "yaml") ?? .text] : [.json]; panel.nameFieldStringValue = filename
        return panel.runModal() == .OK ? panel.url : nil
    }
    func chooseMusic() {
        guard !isLocked else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio, UTType(filenameExtension: "dsf") ?? .data, UTType(filenameExtension: "dff") ?? .data]; panel.allowsOtherFileTypes = true; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        replaceMusic(music + panel.urls.map(\.path))
    }
    func replaceMusic(_ paths: [String], selection: Set<String>? = nil) {
        guard !isLocked else { return }
        let playlist = MusicPlaylist(paths: paths, selected: selection ?? selectedMusic)
        let paths = playlist.paths
        guard paths.count <= 100 else { error = t("Select at most 100 files."); return }
        libraryRevision += 1; let ticket = libraryRevision
        libraryTask?.cancel(); libraryBusy = true
        libraryTask = Task { [weak self] in
            let worker = Task.detached { MusicInspection.inspect(paths) }
            let results = await withTaskCancellationHandler {
                await worker.value
            } onCancel: { worker.cancel() }
            guard !Task.isCancelled, let self, ticket == self.libraryRevision else { return }
            self.music = paths; self.musicInspection = results; self.selectedMusic = playlist.selected
            self.saveMusicLibrary()
            self.libraryBusy = false; self.libraryTask = nil
        }
    }
    func currentPreset() -> PresetDocument {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "HH:mm"
        var preset = PresetDocument(name: presetName.isEmpty ? "My preset" : presetName,
            settings: .init(hours: settings.hours, gain: settings.gainDB, music: settings.selectedMusicSource == .preset ? [] : playbackMusic,
                            dac: selectedDAC?.name, time: formatter.string(from: scheduleDate), days: repeatDays,
                            sessions: sessionCount, awake: settings.keepAwake))
        preset.settings.playback_plan = settings.playbackPlan
        preset.settings.program = settings.program
        preset.settings.music_source = settings.musicSource
        preset.settings.music_preset = settings.musicPreset
        return preset
    }
    func applyPreset(_ preset: PresetDocument) {
        guard !isLocked else { return }
        do { try preset.validate() } catch { self.error = error.localizedDescription; return }
        libraryRevision += 1; let ticket = libraryRevision
        libraryTask?.cancel(); libraryBusy = true
        libraryTask = Task { [weak self] in
            do {
                let presetPaths = preset.settings.selectedMusicSource == .preset ? [] : MusicPlaylist(paths: preset.settings.music, selected: []).paths
                let worker = Task.detached {
                    let results = MusicInspection.inspect(presetPaths)
                    try Task.checkCancellation()
                    if results.allSatisfy({ $0.issue == nil }) { _ = try MusicLoader.duration(presetPaths) }
                    return results
                }
                let inspection = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                guard !Task.isCancelled, let self, ticket == self.libraryRevision else { return }
                try self.completePreset(preset, paths: presetPaths, inspection: inspection)
                self.libraryBusy = false; self.libraryTask = nil
            } catch {
                guard !Task.isCancelled, let self, ticket == self.libraryRevision else { return }
                self.error = self.t(error.localizedDescription)
                self.libraryBusy = false; self.libraryTask = nil
            }
        }
    }
    private func completePreset(_ preset: PresetDocument, paths presetPaths: [String], inspection: [MusicInspection]) throws {
                if let issue = inspection.first(where: { $0.issue != nil }) { throw CinderError.audio(t(issue.issue!) + " " + issue.detail) }
                let usingPresetMusic = preset.settings.selectedMusicSource == .preset
                let combined = usingPresetMusic ? MusicPlaylist(paths: music, selected: selectedMusic) : MusicPlaylist(paths: presetPaths + music, selected: Set(presetPaths))
                try combined.validate()
                let value = preset.settings
                settings.hours = value.hours; settings.keepAwake = value.keep_awake
                settings.playbackPlan = value.playback_plan
                settings.program = value.program
                settings.musicSource = value.music_source; settings.musicPreset = value.music_preset
                dacSelection = dacProfiles.contains { $0.name == value.dac_model } ? (value.dac_model ?? "") : ""
                setGain(Double(value.gain_db))
                settings.resetGainDB = Double(value.gain_db)
                if !usingPresetMusic {
                    music = combined.paths; selectedMusic = combined.selected
                    musicInspection = musicInspection.filter { !combined.selected.contains($0.path) } + inspection
                    // Keep the library display and playback order consistent.
                    musicInspection.sort { music.firstIndex(of: $0.path)! < music.firstIndex(of: $1.path)! }
                    saveMusicLibrary()
                }
                saveMusicPreference()
                repeatDays = value.repeat_days; sessionCount = value.sessions
                let parts = value.time.split(separator: ":").compactMap { Int($0) }
                scheduleDate = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: parts[0], minute: parts[1]), matchingPolicy: .nextTime) ?? ScheduleRules.nextDawn(after: Date())
                resetProgressForConfiguration(); message = t("Preset applied. Playback and scheduling remain manual.")
    }
    func importPreset() {
        guard !isLocked, let url = openJSON(yaml: true) else { return }
        do { let preset = try Documents.read(PresetDocument.self, at: url); try preset.validate(); applyPreset(preset) }
        catch { self.error = error.localizedDescription }
    }
    func exportPreset() {
        guard !isLocked, let url = saveJSON("preset.json", yaml: true) else { return }
        do { let preset = currentPreset(); try preset.validate(); try Documents.write(preset, to: url) }
        catch { self.error = error.localizedDescription }
    }
    func saveNamedPreset() {
        guard !isLocked else { return }
        do {
            let preset = currentPreset(); try preset.validate()
            let digest = SHA256.hash(data: Data(preset.id.utf8)).prefix(10).map { String(format: "%02x", $0) }.joined()
            let filename = safeFilename(preset.id) + "-" + digest + ".json"
            try Documents.write(preset, to: storage.directory.appendingPathComponent("presets").appendingPathComponent(filename))
            presets.removeAll { $0.id == preset.id }; presets.append(preset); presetSelection = preset.id
            message = t("Preset saved.")
        } catch { self.error = error.localizedDescription }
    }
    func safeFilename(_ name: String) -> String {
        let value = name.replacingOccurrences(of: "[^a-zA-Z0-9가-힣ぁ-んァ-ヶ一-龯_-]", with: "_", options: .regularExpression)
        return String(value.prefix(100)).isEmpty ? "device" : String(value.prefix(100))
    }
    func loadCustomizations() {
        let directory = storage.directory.appendingPathComponent("presets")
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files.filter({ $0.pathExtension == "json" }).sorted(by: { $0.path < $1.path }) {
                do { let preset = try Documents.read(PresetDocument.self, at: file); try preset.validate(); presets.removeAll { $0.id == preset.id }; presets.append(preset) }
                catch { self.error = error.localizedDescription }
            }
        }
        let file = storage.directory.appendingPathComponent("swift-theme-v1.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let saved = try Documents.read(ThemeState.self, at: file); try saved.theme?.validate()
                themeChoice = saved.choice; customTheme = saved.theme; audiophile = saved.audiophile
                if let theme = saved.theme { appearance = theme.prefersDark ? "dark" : "light" }
            } catch { self.error = error.localizedDescription }
        }
    }
    func saveTheme() {
        themeSaveTask?.cancel()
        themeSaveTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard !Task.isCancelled else { return }
            self?.persistTheme()
        }
    }
    func applyNativeAppearance() {
        NSApp.appearance = appearance == "system" ? nil : NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        for window in NSApp.windows { window.appearance = NSApp.appearance }
    }
    var effectiveTheme: ThemeDocument? {
        if let customTheme { return customTheme }
        let dark = appearance == "dark" || (appearance == "system" && NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        return themes.first { $0.id == (dark ? "cinder-dark" : "cinder-light") }
    }
    func persistTheme() {
        do { try Documents.write(ThemeState(choice: themeChoice, theme: customTheme, audiophile: audiophile), to: storage.directory.appendingPathComponent("swift-theme-v1.json")) }
        catch { self.error = error.localizedDescription }
    }
    func chooseTheme() {
        if ["system", "light", "dark"].contains(themeChoice) { applyTheme(nil, mode: themeChoice) }
        else if let theme = themes.first(where: { $0.id == themeChoice }) { applyTheme(theme, mode: theme.prefersDark ? "dark" : "light") }
    }
    func applyTheme(_ theme: ThemeDocument?, mode: String) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let changedAppearance = appearance != mode
            appearance = mode
            if changedAppearance { applyNativeAppearance() }
            customTheme = theme
            hexColor = effectiveTheme?.colors[colorToken] ?? "#E3AD59"
        }
        saveUI(); saveTheme()
    }
    func importTheme() {
        guard let url = openJSON() else { return }
        do {
            let theme = try Documents.read(ThemeDocument.self, at: url); try theme.validate()
            themeChoice = "custom"; applyTheme(theme, mode: theme.prefersDark ? "dark" : "light")
        } catch { self.error = error.localizedDescription }
    }
    func exportTheme() {
        guard let theme = effectiveTheme, let url = saveJSON("theme.json") else { return }
        do { try Documents.write(theme, to: url) } catch { self.error = error.localizedDescription }
    }
    func editColor(_ value: String) {
        guard ThemeDocument.validHex(value), var theme = effectiveTheme else { error = t("Use #RRGGBB."); return }
        theme.colors[colorToken] = value; theme.id = "custom"; theme.name = "Custom"
        themeChoice = "custom"; applyTheme(theme, mode: theme.prefersDark ? "dark" : "light")
    }
    func saveConnectedDevice() {
        guard let device else { return }
        let value = ConnectedOutput(name: device.name, uid: device.uid, rate: AudioDevices.sampleRate(device), mac: modelIdentifier, profile: selectedDAC)
        let observedName = device.name.uppercased()
        let inferred = device.builtInHeadphones ? "APPLE" : (observedName.contains("FIIO") ? "FIIO" : (observedName.contains("NICEHCK") ? "NICEHCK" : "Unknown"))
        let folder = storage.directory.appendingPathComponent("dac").appendingPathComponent(safeFilename(selectedDAC?.manufacturer ?? inferred))
        do {
            let file = folder.appendingPathComponent(safeFilename(device.name) + "-" + SHA256.hash(data: Data(device.uid.utf8)).prefix(10).map { String(format: "%02x", $0) }.joined() + ".yaml")
            try Documents.write(value, to: file); message = file.path
        } catch { self.error = error.localizedDescription }
    }
}

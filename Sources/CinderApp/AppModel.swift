import SwiftUI
import AppKit
import CinderCore
import CinderAudio
import CinderPlatform
import CinderStorage

@MainActor final class AppModel: ObservableObject {
    @Published var settings = SessionSettings()
    @Published var state: PlaybackState = .idle
    @Published var planRun: PlaybackPlanRun?
    let playbackDisplay = PlaybackDisplay()
    var snapshot: AudioSnapshot {
        get { playbackDisplay.snapshot }
        set { playbackDisplay.update(newValue) }
    }
    @Published var devices: [OutputDevice] = []
    @Published var selectedUID = ""
    @Published var tab = 0 { didSet { armTimer() } }
    @Published var needle = false
    @Published var error: String?
    @Published var message = ""
    @Published var language = Locale.preferredLanguages.first?.hasPrefix("ko") == true ? "ko" : (Locale.preferredLanguages.first?.hasPrefix("ja") == true ? "ja" : "en")
    @Published var appearance = "system"
    @Published var music: [String] = []
    @Published var musicInspection: [MusicInspection] = []
    @Published var outputRate = 0.0
    @Published var selectedMusic = Set<String>()
    var playbackMusic: [String] { music.filter { selectedMusic.contains($0) } }
    var musicSeconds: Double { musicInspection.reduce(0) { selectedMusic.contains($1.path) ? $0 + $1.seconds : $0 } }
    @Published var libraryBusy = false
    @Published var presets: [PresetDocument] = []
    @Published var presetSelection = ""
    @Published var presetName = ""
    @Published var gainPresetLibrary = GainPresetLibrary()
    @Published var gainPresetSelection = ""
    @Published var scheduleDate = ScheduleRules.tomorrow(at: Date())
    @Published var repeatDays = 0
    @Published var sessionCount = 1
    @Published var armed: Date?
    @Published var scheduleMessage = ""
    @Published var schedulingPresets: [SchedulingPreset] = [
        SchedulingPreset(name: "02:00 · Once", time: "02:00", repeatDays: 0, sessions: 1),
        SchedulingPreset(name: "02:00 · Daily × 3", time: "02:00", repeatDays: 1, sessions: 3)
    ]
    @Published var schedulingPresetSelection = ""
    @Published var schedulingPresetName = ""
    @Published var dacSelection = ""
    @Published var dacProfiles: [DACProfile] = []
    @Published var macProfiles: [MacProfile] = []
    @Published var customTheme: ThemeDocument?
    @Published var themeChoice = "system"
    @Published var themes: [ThemeDocument] = []
    @Published var colorToken = "accent"
    @Published var hexColor = "#E3AD59"
    @Published var audiophile = false
    let scheduleTicker = MainRunLoopTicker()
    var repeatAnchor: Date?
    @Published var repeatRemaining = 0
    var themeSaveTask: Task<Void, Never>?
    var uiSaveTask: Task<Void, Never>?
    var libraryTask: Task<Void, Never>?
    var libraryRevision = 0
    private var sessionGeneration = 0
    let modelIdentifier = AudioDevices.modelIdentifier
    var isLocked: Bool { state.locksSettings || armed != nil || libraryBusy || planRun?.isActive == true }
    var selectedDAC: DACProfile? { dacProfiles.first { $0.name == dacSelection } }
    var macProfile: MacProfile? { macProfiles.first { $0.identifiers.contains(modelIdentifier) } }
    private let audio = PlaybackEngine()
    private let monitor = DeviceMonitor()
    let awake = SleepPrevention()
    let storage = SettingsStore()
    private let ticker = MainRunLoopTicker()
    private var foreground = true
    private var mainWindowIsVisible = false
    private let catalog: [String: [String: String]]
    private let resourceFiles: ResourceFiles
    let releases: [Release]
    var device: OutputDevice? { devices.first { $0.uid == selectedUID } }
    var sessionDurationSeconds: Double { Double(planRun?.currentMinutes ?? settings.durationMinutes) * 60 }
    var remaining: Double { max(0, sessionDurationSeconds - snapshot.elapsed) }

    init() {
        let installedBundle = Bundle.main.resourceURL?.appendingPathComponent("Cinder_CinderApp.bundle")
        let installed = installedBundle.flatMap { Bundle(url: $0)?.resourceURL }
        let directory: URL
        if let installed, FileManager.default.fileExists(atPath: installed.path) { directory = installed }
        else { directory = Bundle.module.resourceURL! }
        let resources = ResourceFiles(root: directory)
        resourceFiles = resources
        var loadingErrors: [String] = []
        var translations: [String: [String: String]] = [:]
        for (language, filename) in [("en", "lang_en"), ("ko", "lang_ko"), ("ja", "lang_jp")] {
            do { translations[language] = try resources.decode([String: String].self, filename: filename + ".json") }
            catch { loadingErrors.append(error.localizedDescription) }
        }
        catalog = translations
        do { releases = try resources.decode(Changelog.self, filename: "changelog.json").releases }
        catch { releases = []; loadingErrors.append(error.localizedDescription) }
        if !loadingErrors.isEmpty { self.error = loadingErrors.joined(separator: "\n") }
        do {
            dacProfiles = try resources.decode([DACProfile].self, filename: "dac-profiles.json")
            macProfiles = try resources.decode([MacProfile].self, filename: "mac-profiles.json")
            for file in ["cinder-dark.json", "cinder-light.json", "cinder-high-contrast.json"] {
                let theme = try resources.decode(ThemeDocument.self, filename: file); try theme.validate(); themes.append(theme)
            }
            for file in ["30-min.json", "20-hours.json", "30-hours.json", "50-hours.json"] {
                let preset = try resources.decode(PresetDocument.self, filename: file); try preset.validate(); presets.append(preset)
            }
        } catch { self.error = error.localizedDescription }
        do { settings = try storage.load() } catch { self.error = error.localizedDescription }
        refreshDevices()
        do {
            if let ui = try storage.loadUI() {
                language = ui.language; appearance = ui.appearance; needle = ui.needle
                if devices.contains(where: { $0.uid == ui.outputUID }) {
                    selectedUID = ui.outputUID
                }
            }
        } catch { self.error = error.localizedDescription }
        monitor.start { [weak self] in self?.devicesChanged() }
        audio.configurationChanged = { [weak self] in self?.fail(CinderError.deviceChanged) }
        loadCustomizations()
        if customTheme == nil && themeChoice == "system" { themeChoice = appearance }
        loadSchedulingPresets()
        loadGainPresets()
        restoreMusicLibrary()
        refreshOutputInfo()
    }
    func t(_ text: String) -> String { catalog[language]?[text] ?? text }
    func refreshDevices() {
        do { devices = try AudioDevices.outputs() }
        catch { devices = []; self.error = error.localizedDescription }
        refreshOutputInfo()
    }
    func refreshOutputInfo() { outputRate = device.map { AudioDevices.sampleRate($0) } ?? 0 }
    var musicProblem: String? {
        do { try settings.validatePlayback() } catch { return t(error.localizedDescription) }
        guard settings.selectedProgram.usesMusic else { return nil }
        if settings.selectedMusicSource == .preset { return nil }
        if settings.selectedProgram == .music && playbackMusic.isEmpty { return t("Choose tracks or Preset Music in Music.") }
        if musicInspection.contains(where: { selectedMusic.contains($0.path) && $0.issue != nil }) { return t("Remove unsupported files before starting.") }
        if musicSeconds > 600 { return t("Select at most 10 minutes of music in total.") }
        if outputRate > 0 && musicSeconds * outputRate * 8 > 256_000_000 { return t("Decoded music exceeds the 256 MB cache at this output rate.") }
        return nil
    }
    private func devicesChanged() {
        let previous = device
        refreshDevices()
        if state.locksSettings || armed != nil, let previous, !devices.contains(previous) { fail(CinderError.deviceChanged) }
        if device == nil { selectedUID = "" }
    }
    func applyHours(_ hours: Double) {
        guard !isLocked else { return }
        var proposed = settings; proposed.hours = hours
        var plan = proposed.selectedPlan; plan.mode = .custom; proposed.playbackPlan = plan
        do { try proposed.validate() } catch { self.error = error.localizedDescription; return }
        settings = proposed; resetProgressForConfiguration(); savePlanPreference()
    }
    func applyMinutes(_ minutes: Int) {
        guard !isLocked else { return }
        do { applyHours(try PlaybackDuration.hours(fromMinutes: minutes)) }
        catch { self.error = t(error.localizedDescription) }
    }
    func resetProgressForConfiguration() {
        planRun = nil
        snapshot = AudioSnapshot()
        if state == .completed { state = .idle }
    }
    func start() {
        guard !isLocked else { return }
        guard device != nil else { error = t("Select an output device first."); return }
        if let musicProblem { error = musicProblem; return }
        do {
            planRun = settings.selectedPlan.mode == .split40
                ? try PlaybackPlanRun(plan: settings.selectedPlan, customMinutes: settings.customDurationMinutes, program: settings.selectedProgram)
                : nil
        } catch { self.error = t(error.localizedDescription); return }
        startCurrentSession()
    }
    func startCurrentSession() {
        guard !state.locksSettings, armed == nil, !libraryBusy else { return }
        guard let device else { fail(CinderError.noDevice); return }
        var selectedSettings = settings
        selectedSettings.hours = sessionDurationSeconds / 3600
        selectedSettings.playbackPlan = nil
        do { try selectedSettings.validatePlayback() } catch { fail(error); return }
        state = .preparing; snapshot = AudioSnapshot(); error = nil
        let selectedMusic = settings.selectedMusicSource == .preset ? [] : playbackMusic
        sessionGeneration += 1
        let ticket = sessionGeneration
        Task {
            guard ticket == sessionGeneration, state == .preparing else { return }
            do {
                let presetURL: URL?
                if selectedSettings.selectedProgram.usesMusic && selectedSettings.selectedMusicSource == .preset {
                    presetURL = try resourceFiles.url(filename: selectedSettings.selectedMusicPreset.filename)
                } else { presetURL = nil }
                try await audio.start(device: device, settings: selectedSettings, music: selectedMusic, presetURL: presetURL)
                guard ticket == sessionGeneration, state == .preparing else { return }
                state = .playing
                if repeatAnchor != nil { scheduleMessage = t("Scheduled session started.") }
                if settings.keepAwake { awake.begin() }
                armTimer()
            } catch is CancellationError { }
            catch { if ticket == sessionGeneration { fail(error) } }
        }
    }
    func togglePause() {
        if state == .playing { audio.pause(); state = .pausing }
        else if state == .paused {
            do { try audio.resume() } catch { fail(error); return }; state = .playing
            if settings.keepAwake { awake.begin() }
        }
        armTimer()
    }
    func stop() {
        sessionGeneration += 1
        cancelSchedule()
        if state == .preparing { audio.shutdown(); awake.end(); state = .idle; return }
        if state == .paused { audio.shutdown(); awake.end(); state = .idle; armTimer(); return }
        guard state.locksSettings else { return }
        audio.stop(); state = .stopping; armTimer()
    }
    var gainControlsDisabled: Bool { device == nil || libraryBusy || armed != nil || [.preparing, .pausing, .stopping].contains(state) }
    var resetGain: Double { settings.resetGainDB ?? 0 }
    var resetGainDescription: String {
        t(settings.resetGainDB == nil ? "Reset to unity gain" : "Reset to default gain") + " · " + GainPolicy.display(resetGain)
    }
    func saveGainDefault() {
        guard !gainControlsDisabled else { return }
        do {
            let gain = settings.gainDB
            try storage.saveGainDefault(gain)
            settings.resetGainDB = gain
        } catch { self.error = error.localizedDescription }
    }
    func adjustGain(_ delta: Double) {
        guard !gainControlsDisabled else { return }
        setGain(min(GainPolicy.maximum, max(GainPolicy.minimum, settings.gainDB + delta)))
    }
    func resetAppGain() {
        guard !gainControlsDisabled else { return }
        setGain(resetGain)
    }
    func setGain(_ gain: Double) {
        do {
            try GainPolicy.validate(gain)
            settings.gainDB = gain
            audio.setGain(gain)
        } catch { self.error = error.localizedDescription }
    }
    func save() {
        do { try storage.save(settings); message = t("Settings saved.") }
        catch { self.error = error.localizedDescription }
    }
    func saveUI() {
        uiSaveTask?.cancel()
        uiSaveTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            guard !Task.isCancelled else { return }
            self?.persistUI()
        }
    }
    func persistUI() {
        do { try storage.saveUI(UIPreferences(language: language, appearance: appearance, needle: needle, outputUID: selectedUID)) }
        catch { self.error = error.localizedDescription }
    }
    func active(_ value: Bool) { foreground = value; armTimer() }
    func mainWindowVisible(_ value: Bool) { mainWindowIsVisible = value; armTimer() }
    private func armTimer() {
        guard state.locksSettings, state != .preparing, state != .paused else { ticker.stop(); return }
        let interval = state == .stopping || state == .pausing || (foreground && mainWindowIsVisible && tab == 0 && state == .playing) ? 0.1 : 1.0
        ticker.start(interval: interval) { [weak self] in self?.tick() }
    }
    private func tick() {
        var value = audio.snapshot()
        if value.paused { value.peakDB = -.infinity; value.rmsDB = -.infinity }
        snapshot = value
        if snapshot.finished {
            let stopped = state == .stopping
            audio.shutdown(); awake.end(); state = stopped ? .idle : .completed; armTimer()
            if !stopped {
                planRun?.finishSession(at: Date())
                if let next = planRun?.nextStart {
                    snapshot = AudioSnapshot()
                    armed = next; scheduleMessage = t("Resting between sessions")
                    armScheduleTimer()
                } else { rearmRepeat() }
            }
        } else if snapshot.paused && state == .pausing {
            audio.suspendAfterPause(); state = .paused; awake.end(); armTimer()
        }
    }
    func fail(_ failure: Error) {
        sessionGeneration += 1
        cancelSchedule()
        audio.shutdown(); awake.end(); state = .failed; armTimer(); error = failure.localizedDescription
    }
    func shutdown() {
        libraryRevision += 1; libraryTask?.cancel(); libraryTask = nil
        uiSaveTask?.cancel(); persistUI()
        themeSaveTask?.cancel(); persistTheme()
        sessionGeneration += 1; cancelSchedule(); ticker.stop(); monitor.stop(); audio.shutdown(); awake.end()
    }
}

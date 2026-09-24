import Foundation
import CryptoKit
import CinderCore
import CinderStorage

extension AppModel {
    func currentSchedulingPreset() throws -> SchedulingPreset {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "HH:mm"
        let preset = SchedulingPreset(name: schedulingPresetName.trimmingCharacters(in: .whitespacesAndNewlines),
            time: formatter.string(from: scheduleDate), repeatDays: repeatDays, sessions: repeatDays == 0 ? 1 : sessionCount)
        try preset.validate(); return preset
    }
    func applySchedulingPreset(_ preset: SchedulingPreset) {
        guard !isLocked else { return }
        do {
            let date = try preset.nextDate(after: Date())
            scheduleDate = date; repeatDays = preset.repeat_days; sessionCount = preset.sessions
            schedulingPresetName = preset.name
            scheduleMessage = t("Scheduling preset applied. Review the date, then press Set Schedule.")
        } catch { self.error = error.localizedDescription }
    }
    func loadSchedulingPresets() {
        let folder = storage.directory.appendingPathComponent("scheduling-presets")
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            for file in files.filter({ ["json", "yaml", "yml"].contains($0.pathExtension.lowercased()) }).sorted(by: { $0.path < $1.path }) {
                do {
                    let preset = try Documents.read(SchedulingPreset.self, at: file); try preset.validate()
                    schedulingPresets.removeAll { $0.id == preset.id }; schedulingPresets.append(preset)
                } catch { self.error = error.localizedDescription }
            }
        } catch { self.error = error.localizedDescription }
    }
    func saveSchedulingPreset() {
        guard !isLocked else { return }
        do {
            let preset = try currentSchedulingPreset()
            let digest = SHA256.hash(data: Data(preset.name.utf8)).prefix(10).map { String(format: "%02x", $0) }.joined()
            let file = storage.directory.appendingPathComponent("scheduling-presets").appendingPathComponent(digest + ".json")
            try Documents.write(preset, to: file)
            schedulingPresets.removeAll { $0.id == preset.id }; schedulingPresets.append(preset)
            schedulingPresetSelection = preset.id; scheduleMessage = t("Scheduling preset saved.")
        } catch { self.error = error.localizedDescription }
    }
    func importSchedulingPreset() {
        guard !isLocked, let file = openJSON(yaml: true) else { return }
        do { let preset = try Documents.read(SchedulingPreset.self, at: file); try preset.validate(); applySchedulingPreset(preset) }
        catch { self.error = error.localizedDescription }
    }
    func exportSchedulingPreset() {
        guard !isLocked else { return }
        do {
            let preset = try currentSchedulingPreset()
            guard let file = saveJSON("scheduling-preset.json", yaml: true) else { return }
            try Documents.write(preset, to: file)
        } catch { self.error = error.localizedDescription }
    }
}

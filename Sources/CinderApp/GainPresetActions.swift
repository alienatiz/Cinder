import Foundation
import CinderCore
import CinderStorage

extension AppModel {
    var selectedGainPreset: GainPreset? { gainPresetLibrary.presets.first { $0.id == gainPresetSelection } }
    func loadGainPresets() {
        do { gainPresetLibrary = try GainPresetStore(directory: storage.directory).load() }
        catch { self.error = t(error.localizedDescription) }
    }
    @discardableResult func saveGainPreset(name: String, replacing id: String? = nil) -> Bool {
        guard !gainControlsDisabled else { return false }
        do {
            var candidate = gainPresetLibrary
            let preset = GainPreset(id: id ?? UUID().uuidString, name: name, gainDB: settings.gainDB,
                                    outputUID: device?.uid, outputName: device?.name)
            try candidate.upsert(preset)
            try GainPresetStore(directory: storage.directory).save(candidate)
            gainPresetLibrary = candidate; gainPresetSelection = preset.id
            return true
        } catch { self.error = t(error.localizedDescription); return false }
    }
    func applyGainPreset() {
        guard !gainControlsDisabled, let preset = selectedGainPreset else { return }
        do { try preset.validate() } catch { self.error = t(error.localizedDescription); return }
        setGain(preset.gainDB)
        settings.resetGainDB = preset.gainDB
        // Only explicit Save in the gain row changes the startup gain.
    }
    func deleteGainPreset() {
        guard !gainControlsDisabled, let preset = selectedGainPreset else { return }
        do {
            var candidate = gainPresetLibrary
            candidate.presets.removeAll { $0.id == preset.id }
            try GainPresetStore(directory: storage.directory).save(candidate)
            gainPresetLibrary = candidate; gainPresetSelection = ""
        } catch { self.error = t(error.localizedDescription) }
    }
}

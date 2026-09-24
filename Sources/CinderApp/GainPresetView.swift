import SwiftUI
import CinderCore

@MainActor struct GainPresetView: View {
    @ObservedObject var model: AppModel
    @State private var naming = false
    @State private var name = ""
    var body: some View {
        Panel(title: model.t("Gain Presets")) {
            HStack(spacing: 10) {
                Picker(model.t("Earphones"), selection: $model.gainPresetSelection) {
                    Text(model.t("Select preset")).tag("")
                    ForEach(model.gainPresetLibrary.presets) { preset in
                        Text(preset.name + " · " + GainPolicy.display(preset.gainDB)).tag(preset.id)
                    }
                }
                Button(model.t("Apply"), action: model.applyGainPreset).disabled(model.selectedGainPreset == nil)
                Button(model.t("Save As")) { name = ""; naming = true }
                    .popover(isPresented: $naming) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.t("Save gain preset")).font(.headline)
                            TextField(model.t("Preset name"), text: $name)
                            Text(GainPolicy.display(model.settings.gainDB)).monospacedDigit()
                            Text(model.device?.name ?? "").foregroundStyle(.secondary)
                            HStack {
                                Button(model.t("Cancel")) { naming = false }
                                Spacer()
                                Button(model.t("Save")) {
                                    if model.saveGainPreset(name: name) { naming = false }
                                }.disabled(model.gainControlsDisabled || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }.padding(20).frame(width: 340)
                    }
                Button(model.t("Update")) {
                    if let preset = model.selectedGainPreset { model.saveGainPreset(name: preset.name, replacing: preset.id) }
                }.disabled(model.selectedGainPreset == nil)
                Button(model.t("Delete"), action: model.deleteGainPreset).disabled(model.selectedGainPreset == nil)
                InfoHint(text: model.t("Gain preset help"))
            }.disabled(model.gainControlsDisabled)
            if let preset = model.selectedGainPreset, let uid = preset.outputUID, uid != model.selectedUID {
                Text(model.t("Saved with a different output. Check the volume before applying.") + " · " + (preset.outputName ?? ""))
                    .foregroundStyle(.secondary)
            }
        }.onChange(of: model.gainControlsDisabled) { _, disabled in if disabled { naming = false } }
    }
}

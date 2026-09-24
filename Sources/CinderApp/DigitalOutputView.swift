import SwiftUI
import CinderCore

@MainActor struct DigitalOutputView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var display: PlaybackDisplay
    init(model: AppModel) { self.model = model; self.display = model.playbackDisplay }
    var body: some View {
                Panel(title: model.t("Digital Output"), compact: true) {
                    DigitalMeter(peak: display.snapshot.peakDB, rms: display.snapshot.rmsDB, needle: model.needle)
                    HStack(spacing: 6) {
                        Text(model.t("App gain") + " " + GainPolicy.display(model.settings.gainDB)).monospacedDigit().fixedSize()
                        Spacer(minLength: 0)
                        ForEach([-2, -1, 1, 2], id: \.self) { step in
                            Button("\(step > 0 ? "+" : "−")\(abs(step)) dB") { model.adjustGain(Double(step)) }
                                .disabled(step < 0 ? model.settings.gainDB <= GainPolicy.minimum : model.settings.gainDB >= GainPolicy.maximum)
                        }
                        Button(model.t("Save"), action: model.saveGainDefault).help(model.t("Save current gain as the default for Reset and the next launch."))
                        Button(model.t("Reset"), action: model.resetAppGain).help(model.resetGainDescription)
                    }.controlSize(.small).disabled(model.gainControlsDisabled)
                    Text(model.resetGainDescription).font(.caption).foregroundStyle(.secondary)
                    Text(model.t("Digital level before system volume; not measured sound pressure.")).foregroundStyle(.secondary)
                }
    }
}

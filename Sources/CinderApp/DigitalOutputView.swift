import SwiftUI
import CinderCore

@MainActor struct DigitalOutputView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var display: PlaybackDisplay
    private let detailed: Bool
    init(model: AppModel, detailed: Bool = false) {
        self.model = model; self.display = model.playbackDisplay; self.detailed = detailed
    }
    var body: some View {
                Panel(title: model.t("Digital Output"), compact: true) {
                    DigitalMeter(peak: display.snapshot.peakDB, rms: display.snapshot.rmsDB, needle: model.needle)
                    if detailed {
                        HStack {
                            Slider(value: Binding(get: { model.settings.gainDB }, set: { model.setGain($0) }), in: GainPolicy.minimum...GainPolicy.maximum, step: 1)
                                .accessibilityLabel(model.t("App gain"))
                            TextField(model.t("App gain"), value: Binding(get: { model.settings.gainDB }, set: { model.setGain($0) }), format: .number.precision(.fractionLength(0...2)))
                                .frame(width: 70)
                            Text("dB")
                        }.disabled(model.gainControlsDisabled)
                    }
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
                    if detailed {
                        HStack(spacing: 6) {
                            Text(model.t("Signal amplitude") + String(format: " · %.2f%%", pow(10, model.settings.gainDB / 20) * 100)).monospacedDigit()
                            InfoHint(text: model.t("Manual app gain: −60 to 0 dB. New settings start at −30 dB; this is not an SPL calibration.") + "\n" + model.t("Digital amplitude relative to unity. DAC hardware gain and filters are controlled on the device or in its manufacturer app."))
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    Text(model.t("Digital level before system volume; not measured sound pressure.")).foregroundStyle(.secondary)
                }
    }
}

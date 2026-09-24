import SwiftUI
import CinderCore

/// The dial and Settings use the same editor and validation path.
@MainActor struct DurationControl: View {
    @ObservedObject var model: AppModel
    var seconds: Double
    var dial = false
    @State private var editing = false
    @State private var draftMinutes = 1800

    var body: some View {
        Button {
            draftMinutes = model.settings.durationMinutes
            editing = true
        } label: {
            if dial {
                Text(Cycle.time(seconds))
                    .font(.system(size: 36, weight: .light, design: .rounded)).monospacedDigit()
            } else {
                Label(Cycle.time(seconds), systemImage: "clock").monospacedDigit()
            }
        }
        .buttonStyle(.plain).disabled(model.isLocked || model.settings.selectedPlan.mode != .custom)
        .help(model.t(model.settings.selectedPlan.mode == .custom ? "Click the time to set playback duration." : "Choose Custom duration in Quick Play to change this time."))
        .accessibilityLabel(Text(model.t("Playback duration")))
        .accessibilityValue(Text(Cycle.time(seconds)))
        .popover(isPresented: $editing) {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.t("Playback duration")).font(.headline)
                DurationFields(minutes: $draftMinutes, hoursLabel: model.t("Hours"), minutesLabel: model.t("Minutes"))
                HStack {
                    ForEach([60, 120, 240, 2400], id: \.self) { minutes in
                        Button("\(minutes / 60) h") { draftMinutes = minutes }
                    }
                }
                Text(model.t("Choose 1 minute to 1000 hours in whole minutes.")).foregroundStyle(.secondary)
                HStack {
                    Button(model.t("Cancel")) { editing = false }
                    Spacer()
                    Button(model.t("Apply")) { model.applyMinutes(draftMinutes); editing = false }
                        .disabled(model.isLocked || !(1...PlaybackDuration.maximumMinutes).contains(draftMinutes))
                        .keyboardShortcut(.defaultAction)
                }
            }.padding(20).frame(width: 360)
        }
        .onChange(of: model.isLocked) { _, locked in if locked { editing = false } }
    }
}

struct DurationFields: View {
    @Binding var minutes: Int
    let hoursLabel: String
    let minutesLabel: String
    var maximumMinutes = PlaybackDuration.maximumMinutes
    private var hours: Binding<Int> {
        Binding(get: { minutes / 60 }, set: { value in
            minutes = min(maximumMinutes, max(0, min(maximumMinutes / 60, value)) * 60 + minutes % 60)
        })
    }
    private var minutePart: Binding<Int> {
        Binding(get: { minutes % 60 }, set: { value in
            minutes = min(maximumMinutes, (minutes / 60) * 60 + max(0, min(59, value)))
        })
    }
    var body: some View {
        HStack(spacing: 24) {
            field(hoursLabel, value: hours, range: 0...(maximumMinutes / 60))
            field(minutesLabel, value: minutePart, range: 0...59).disabled(minutes >= maximumMinutes && maximumMinutes % 60 == 0)
        }
    }
    private func field(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField(title, value: value, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder).frame(width: 72).monospacedDigit()
                    .accessibilityLabel(Text(title))
                Stepper(title, value: value, in: range).labelsHidden().accessibilityLabel(Text(title))
            }
        }
    }
}

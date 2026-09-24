import SwiftUI
import CinderCore

@MainActor struct MenuQuickPlaySettings: View {
    @ObservedObject var model: AppModel
    @Binding var editingDuration: Bool
    @State private var draftMinutes = 60

    private var durationLabel: String {
        model.settings.selectedPlan.mode == .custom
            ? Cycle.time(model.settings.durationSeconds)
            : model.t(model.settings.selectedPlan.mode.label)
    }
    private var draftIssue: String? {
        do {
            let hours = try PlaybackDuration.hours(fromMinutes: draftMinutes)
            var settings = model.settings
            settings.hours = hours
            var plan = settings.selectedPlan; plan.mode = .custom; settings.playbackPlan = plan
            try settings.validatePlayback()
            return nil
        } catch { return model.t(error.localizedDescription) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker(model.t("Output device"), selection: Binding(get: { model.selectedUID }, set: { model.selectOutput($0) })) {
                    Text(model.t("Select output")).tag("")
                    ForEach(model.devices) { Text($0.name).tag($0.uid) }
                }
                .labelsHidden().frame(maxWidth: .infinity)
                Button(action: model.refreshDevices) { Label(model.t("Refresh"), systemImage: "arrow.clockwise") }
                    .labelStyle(.iconOnly).help(model.t("Refresh"))
            }
            HStack {
                Text(model.t("Playback duration")).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach([1, 2, 4, 8], id: \.self) { hours in
                        Button(String(format: model.t("%d-hour session"), hours)) {
                            editingDuration = false
                            model.applyMinutes(hours * 60)
                        }
                    }
                    Button(model.t("40 hours · continuous")) {
                        editingDuration = false; model.selectPlanMode(.continuous40)
                    }
                    Button(model.t("40 hours · split")) {
                        editingDuration = false; model.selectPlanMode(.split40)
                    }
                    Divider()
                    Button(model.t("Custom duration") + "…") {
                        draftMinutes = model.settings.durationMinutes; editingDuration = true
                    }
                } label: {
                    Text(durationLabel).monospacedDigit()
                }
                .fixedSize().accessibilityLabel(Text(model.t("Playback duration")))
                .accessibilityValue(Text(durationLabel))
            }
            if editingDuration {
                DurationFields(minutes: $draftMinutes, hoursLabel: model.t("Hours"), minutesLabel: model.t("Minutes"))
                if let issue = draftIssue {
                    Text(issue).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button(model.t("Cancel")) { editingDuration = false }
                    Spacer()
                    Button(model.t("Apply")) {
                        guard !model.isLocked, draftIssue == nil else { return }
                        model.applyMinutes(draftMinutes); editingDuration = false
                    }.disabled(draftIssue != nil)
                }
            } else if model.settings.selectedPlan.mode == .split40 {
                Text(String(format: model.t("Session %@ · rest %@"),
                            Cycle.time(Double(model.settings.selectedPlan.sessionMinutes * 60)),
                            Cycle.time(Double(model.settings.selectedPlan.restMinutes * 60))))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(model.planSummary).font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(model.isLocked)
        .onChange(of: model.isLocked) { _, locked in if locked { editingDuration = false } }
        .onChange(of: model.settings) { _, _ in editingDuration = false }
    }
}

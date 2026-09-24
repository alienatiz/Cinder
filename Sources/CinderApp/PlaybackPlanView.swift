import SwiftUI
import CinderCore

@MainActor struct PlaybackPlanView: View {
    @ObservedObject var model: AppModel
    @State private var editingSplit = false
    @State private var sessionMinutes = 240
    @State private var restMinutes = 60

    private var draft: PlaybackPlan { PlaybackPlan(mode: .split40, sessionMinutes: sessionMinutes, restMinutes: restMinutes) }
    private var draftIssue: String? {
        do { try draft.validatePlayback(customMinutes: model.settings.customDurationMinutes, program: model.settings.selectedProgram); return nil }
        catch { return model.t(error.localizedDescription) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(model.t("Session plan")).font(.headline)
                Picker(model.t("Session plan"), selection: Binding(get: { model.settings.selectedPlan.mode }, set: { model.selectPlanMode($0) })) {
                    ForEach(PlaybackPlan.Mode.allCases, id: \.self) { Text(model.t($0.label)).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().disabled(model.isLocked)
                InfoHint(text: model.t("Playback plan help"))
            }
            HStack(spacing: 12) {
                if model.settings.selectedPlan.mode == .split40 {
                    Button {
                        sessionMinutes = model.settings.selectedPlan.sessionMinutes
                        restMinutes = model.settings.selectedPlan.restMinutes
                        editingSplit = true
                    } label: {
                        Label(String(format: model.t("Session %@ · rest %@"),
                                     Cycle.time(Double(model.settings.selectedPlan.sessionMinutes * 60)),
                                     Cycle.time(Double(model.settings.selectedPlan.restMinutes * 60))), systemImage: "slider.horizontal.3")
                    }.disabled(model.isLocked)
                } else if model.settings.selectedPlan.mode == .custom {
                    DurationControl(model: model, seconds: model.settings.durationSeconds)
                }
                Text(model.planSummary).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if model.settings.selectedPlan.mode == .split40 {
                    Text(model.t("Including rests") + " · " + Cycle.time(Double(model.settings.planElapsedMinutes * 60)))
                        .foregroundStyle(.secondary).monospacedDigit()
                }
            }.font(.system(size: 13))
            if let timing = model.plannedTiming {
                HStack(spacing: 12) {
                    Text(model.t("Session time") + " · " + Cycle.time(timing.sessionSeconds))
                    Text(model.t("Signal stages") + " · " + Cycle.time(timing.signalSeconds))
                    Text(model.t("Cycle rests") + " · " + Cycle.time(timing.cycleRestSeconds))
                    if timing.betweenSessionRestSeconds > 0 {
                        Text(model.t("Between sessions") + " · " + Cycle.time(timing.betweenSessionRestSeconds))
                    }
                    InfoHint(text: model.t("Session time includes cycle rests. Signal stages exclude those rests, but may contain silence in music. Pauses and preparation delay the estimated finish."))
                }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            if let progress = model.planProgress { Text(progress).font(.system(size: 13)).foregroundStyle(.secondary) }
        }
        .popover(isPresented: $editingSplit) {
            VStack(alignment: .leading, spacing: 14) {
                Text(model.t("Split 40 hours")).font(.headline)
                Text(model.t("Session duration"))
                DurationFields(minutes: $sessionMinutes, hoursLabel: model.t("Hours"), minutesLabel: model.t("Minutes"), maximumMinutes: PlaybackPlan.targetMinutes)
                Text(model.t("Rest between sessions"))
                DurationFields(minutes: $restMinutes, hoursLabel: model.t("Hours"), minutesLabel: model.t("Minutes"), maximumMinutes: PlaybackPlan.maximumRestMinutes)
                if let runs = try? draft.sessions(customMinutes: model.settings.customDurationMinutes),
                   let elapsed = try? draft.elapsedMinutes(customMinutes: model.settings.customDurationMinutes) {
                    Text(String(format: model.t("%d sessions · last session %@"), runs.count, Cycle.time(Double((runs.last ?? 0) * 60))))
                    Text(model.t("Including rests") + " · " + Cycle.time(Double(elapsed * 60))).foregroundStyle(.secondary)
                }
                Text(model.t("The next session starts after the rest. Keep the app open; Stop cancels the remaining plan."))
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let issue = draftIssue { Text(issue).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
                HStack {
                    Button(model.t("Cancel")) { editingSplit = false }
                    Spacer()
                    Button(model.t("Apply")) {
                        model.applySplitPlan(sessionMinutes: sessionMinutes, restMinutes: restMinutes)
                        editingSplit = false
                    }.disabled(draftIssue != nil || model.isLocked).keyboardShortcut(.defaultAction)
                }
            }.padding(20).frame(width: 430)
        }
        .onChange(of: model.isLocked) { _, locked in if locked { editingSplit = false } }
    }
}

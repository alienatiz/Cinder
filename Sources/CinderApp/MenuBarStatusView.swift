import SwiftUI
import AppKit
import CinderCore

/// Uses the app's existing playback owner; closing either view cannot end a session.
@MainActor struct MenuBarStatusView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var display: PlaybackDisplay
    @Environment(\.openWindow) private var openWindow

    init(model: AppModel) { self.model = model; self.display = model.playbackDisplay }

    private var status: String {
        if model.planRun?.nextStart != nil { return model.t("Resting between sessions") }
        if model.armed != nil { return model.t("Waiting for scheduled start — no sound") }
        if model.state == .completed, model.planRun?.phase == .cancelled { return model.t("idle") }
        return model.t(model.state.rawValue)
    }
    private var symbol: String {
        if model.armed != nil { return "clock" }
        switch model.state {
        case .playing: return "waveform"
        case .paused, .pausing: return "pause.fill"
        case .failed: return "exclamationmark.triangle"
        case .completed: return model.planRun?.phase == .cancelled ? "flame.fill" : "checkmark.circle"
        default: return "flame.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).font(.title2).frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cinder").font(.headline)
                    Text(status).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let target = model.armed {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    timeRow("Starts in", seconds: max(0, target.timeIntervalSince(context.date)))
                }
                Text(target.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
            } else if model.state.locksSettings || (model.state == .completed && display.snapshot.finished) {
                timeRow("Remaining", seconds: max(0, model.sessionDurationSeconds - display.snapshot.elapsed))
                ProgressView(value: min(1, max(0, display.snapshot.elapsed / model.sessionDurationSeconds)))
                    .accessibilityLabel(Text(model.t("Current Progress")))
                Text(model.t(model.settings.selectedProgram == .fullCycle
                    ? Cycle.names[Cycle.step(at: max(0, display.snapshot.elapsed - (model.state == .completed ? 0.001 : 0)))]
                    : model.settings.selectedProgram.label))
                    .foregroundStyle(.secondary)
            }
            if let run = model.planRun, run.isActive || run.phase == .completed {
                Text(String(format: model.t("%d of %d sessions completed"), run.completedSessions, run.sessions.count))
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let device = model.device {
                Label(device.name, systemImage: "speaker.wave.2")
                    .font(.callout).lineLimit(2)
                    .accessibilityLabel(Text(model.t("Output device") + ": " + device.name))
            }
            if let error = model.error {
                Text(model.t(error)).font(.callout).foregroundStyle(.red).lineLimit(3)
            }
            if model.state.locksSettings || model.armed != nil {
                HStack {
                    if model.armed == nil {
                        Button(action: model.togglePause) {
                            Label(model.t(model.state == .paused ? "Resume" : "Pause"),
                                  systemImage: model.state == .paused ? "play.fill" : "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(![.playing, .paused].contains(model.state))
                    }
                    Button(action: model.stop) {
                        Label(model.t(model.armed != nil ? "Cancel Schedule" : "Stop"), systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(model.state == .stopping)
                }.controlSize(.large)
            }
            Divider()
            HStack {
                Button(model.t("Open Cinder")) {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                Spacer()
                Button(model.t("Quit Cinder")) { NSApp.terminate(nil) }
                    .help(model.t("Quit stops playback and cancels pending sessions."))
            }
            Text(model.t("Closing the window keeps playback and schedules running."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 320)
    }

    private func timeRow(_ title: String, seconds: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.t(title)).foregroundStyle(.secondary)
            Spacer()
            Text(Cycle.time(seconds)).font(.title2).monospacedDigit()
        }
    }
}

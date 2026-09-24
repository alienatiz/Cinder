import SwiftUI
import CinderCore

@MainActor struct CurrentProgressView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var display: PlaybackDisplay
    init(model: AppModel) { self.model = model; self.display = model.playbackDisplay }
    private var runningDisplay: Bool { model.state.locksSettings }
    var body: some View {
        Panel(title: model.t("Current Progress")) {
            ActionPicker(model: model)
            ZStack {
                Circle().stroke(.secondary.opacity(0.15), lineWidth: 6)
                Circle().trim(from: 0, to: min(1, display.snapshot.elapsed / (model.settings.durationSeconds)))
                    .stroke(.orange.opacity(0.7), style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 8) {
                    DurationControl(model: model, seconds: PlaybackDuration.dialSeconds(configuredSeconds: model.settings.durationSeconds, elapsed: display.snapshot.elapsed, state: model.state), dial: true)
                    HStack(spacing: 4) {
                        Text(model.t(runningDisplay ? "Remaining" : "Playback duration")).foregroundStyle(.secondary)
                        if !model.isLocked { Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }.frame(height: 200).padding(.horizontal, 30)
            HStack {
                Text(model.t("Elapsed") + " " + Cycle.time(display.snapshot.elapsed))
                Spacer()
                Text(model.t("Total") + " " + Cycle.time(model.settings.durationSeconds))
            }.monospacedDigit()
            let position = model.state == .completed ? max(0, display.snapshot.elapsed - 0.001) : display.snapshot.elapsed
            if model.settings.selectedProgram == .fullCycle {
                let step = Cycle.step(at: position)
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        Text("\(index + 1)").frame(maxWidth: .infinity).padding(.vertical, 5)
                            .background(index == step ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08), in: Capsule())
                            .help(model.t(Cycle.names[index]) + " · " + Cycle.time(Double(Cycle.seconds[index])))
                            .accessibilityLabel(Text(model.t(Cycle.names[index])))
                    }
                }
                Text("\(model.t("Cycle")) \(Int(position / 3600) + 1) · \(step + 1)/6 · \(model.t(Cycle.names[step]))")
            } else { Text(model.t(model.settings.selectedProgram.label)) }
            HStack {
                Text(String(format: "%.1f%%", 100 * display.snapshot.elapsed / (model.settings.durationSeconds)))
                Spacer()
                Text(model.t("Sound") + " " + Cycle.time(display.snapshot.sound))
            }.foregroundStyle(.secondary).monospacedDigit()
            if model.state == .playing { Text(model.t("Expected end") + " · " + Date().addingTimeInterval(model.remaining).formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary) }
        }
    }
}

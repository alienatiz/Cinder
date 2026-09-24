import SwiftUI
import CinderCore

struct DurationPicker: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 16) {
            Text(model.t("Playback duration"))
            DurationControl(model: model, seconds: model.settings.durationSeconds)
            Text(model.t(model.settings.selectedPlan.mode == .custom ? "Click the time to set playback duration." : "Choose Custom duration in Quick Play to change this time.")).foregroundStyle(.secondary)
          }
          ActionPicker(model: model)
        }.disabled(model.isLocked)
    }
}

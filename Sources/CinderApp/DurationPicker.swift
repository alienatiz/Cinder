import SwiftUI
import CinderCore

struct DurationPicker: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 16) {
            Text(model.t("Playback duration"))
            DurationControl(model: model, seconds: model.settings.durationSeconds)
            Text(model.t("Click the time to set playback duration.")).foregroundStyle(.secondary)
          }
          ActionPicker(model: model)
        }.disabled(model.isLocked)
    }
}

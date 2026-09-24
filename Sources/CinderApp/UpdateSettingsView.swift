import SwiftUI
import CinderCore

struct UpdateSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            Panel(title: model.t("Update channel")) {
                Picker(model.t("Update channel"), selection: Binding(
                    get: { model.updateChannel },
                    set: { model.selectUpdateChannel($0) }
                )) {
                    Text(model.t("Dev · Development")).tag(UpdateChannel.dev)
                    Text(model.t("Stable · Official releases")).tag(UpdateChannel.stable)
                }
                .pickerStyle(.segmented)
                Text(model.updateChannel == .dev
                     ? model.t("Development versions for trying new features and fixes.")
                     : model.t("Official versions published after release validation."))
                Label(model.t("Channel choice is saved automatically."), systemImage: "internaldrive")
                    .font(.callout).foregroundStyle(.secondary)
                Text(model.t("Changing this choice keeps your installed app and playback unchanged."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Panel(title: model.t("Installed app")) {
                Text(Identity.name).font(.title3.weight(.semibold))
                Text(Identity.version + " · " + Identity.releaseChannel)
                    .monospaced().textSelection(.enabled)
                Divider()
                Label(model.t("Updates are not available yet"), systemImage: "clock")
                Text(model.t("No stable release has been published. This version saves your channel choice; downloading and installing updates will be added later."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

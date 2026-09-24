import SwiftUI
import CinderAudio
import CinderCore

struct MusicFileList: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if !model.musicInspection.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.musicInspection) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Toggle(isOn: Binding(get: { model.selectedMusic.contains(item.path) }, set: { model.selectMusic(item.path, included: $0) })) {
                                    Text(URL(fileURLWithPath: item.path).lastPathComponent).lineLimit(1).help(item.path)
                                }.disabled(model.isLocked || (item.issue != nil && !model.selectedMusic.contains(item.path)))
                                Spacer()
                                Button(model.t("Remove")) {
                                    model.replaceMusic(model.music.filter { $0 != item.path })
                                }.disabled(model.isLocked)
                            }
                            Text(item.format + " · " + (item.bits > 0 ? "\(item.bits)-bit" : model.t("Bit depth unknown")) + String(format: " · %.0f Hz · %d ch · ", item.sampleRate, item.channels) + Cycle.time(item.seconds))
                                .foregroundStyle(.secondary)
                            if let issue = item.issue {
                                HStack(spacing: 4) {
                                    Text(model.t(issue)).foregroundStyle(.red)
                                    InfoHint(text: model.t(issue), symbol: "info.circle.fill", label: model.t(issue), tint: .red)
                                }
                                if !item.detail.isEmpty {
                                    DisclosureGroup(model.t("Technical details")) {
                                        Text(item.detail).font(.caption).textSelection(.enabled)
                                    }
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Text(model.t("Header and initial decode"))
                                    InfoHint(text: model.t("Music verification help"), symbol: "checkmark.circle.fill", label: model.t("Checks passed"), tint: .green)
                                }
                                if model.outputRate > 0 {
                                    Text(String(format: "PCM · %.0f → %.0f Hz · 2 ch", item.sampleRate, model.outputRate))
                                } else { Text(model.t("Select output to see conversion details.")) }
                            }
                        }
                        Divider()
                    }
                }
            }.frame(height: 380)
        }
    }
}

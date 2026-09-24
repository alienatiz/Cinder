import SwiftUI
import CinderAudio
import CinderCore

struct MusicFileList: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var page = 0
    private var items: [MusicInspection] {
        model.musicInspection.filter { query.isEmpty || URL(fileURLWithPath: $0.path).lastPathComponent.localizedCaseInsensitiveContains(query) }
    }
    private var pageCount: Int { max(1, (items.count + 2) / 3) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(model.t("Search music"), text: $query).onChange(of: query) { _, _ in page = 0 }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.dropFirst(min(page, pageCount - 1) * 3).prefix(3))) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle(isOn: Binding(get: { model.selectedMusic.contains(item.path) }, set: { model.selectMusic(item.path, included: $0) })) {
                                Text(URL(fileURLWithPath: item.path).lastPathComponent).lineLimit(1).help(item.path)
                            }.disabled(model.isLocked || (item.issue != nil && !model.selectedMusic.contains(item.path)))
                            Spacer()
                            Button(model.t("Remove")) { model.replaceMusic(model.music.filter { $0 != item.path }) }.disabled(model.isLocked)
                        }
                        Text(item.format + String(format: " · %.0f Hz · %d ch · ", item.sampleRate, item.channels) + Cycle.time(item.seconds))
                            .foregroundStyle(.secondary).lineLimit(1)
                        HStack(spacing: 4) {
                            if let issue = item.issue {
                                Text(model.t(issue)).foregroundStyle(.red).lineLimit(1)
                                InfoHint(text: model.t(issue) + (item.detail.isEmpty ? "" : "\n" + item.detail), label: model.t("Technical details"), tint: .red)
                            } else {
                                Text(model.t("Header and initial decode"))
                                InfoHint(text: model.t("Music verification help") + "\n" + (item.bits > 0 ? "\(item.bits)-bit" : model.t("Bit depth unknown")) + String(format: " · PCM %.0f → %.0f Hz", item.sampleRate, model.outputRate), symbol: "checkmark.circle.fill", label: model.t("Checks passed"), tint: .green)
                            }
                        }.font(.caption)
                        Divider()
                    }
                }
                if items.isEmpty { Text(model.t("No matching music.")).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }.frame(height: 250, alignment: .top)
            PageControls(model: model, page: $page, count: pageCount)
        }.onChange(of: pageCount) { _, count in page = min(page, count - 1) }
    }
}

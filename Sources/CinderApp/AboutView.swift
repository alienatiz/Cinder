import SwiftUI
import CinderCore

struct AboutView: View {
    @ObservedObject var model: AppModel
    @State private var changelog = false
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Panel(title: model.t("About Cinder")) {
                Text("Cinder · " + Identity.version).font(.title2)
                Text(model.t("A timed audio signal player with planned rests and local session history."))
                Text(model.t("Requires Apple Silicon and macOS 14 or later. Core playback works offline."))
                Text(model.t("Closing the window keeps Cinder in the menu bar. Quit Cinder stops playback and cancels pending schedules."))
                Button(model.t("Changelog")) { changelog = true }
                Link(model.t("Project and downloads"), destination: URL(string: "https://github.com/alienatiz/Cinder")!)
                Link(model.t("Report an issue"), destination: URL(string: "https://github.com/alienatiz/Cinder/issues")!)
            }
            Panel(title: model.t("Playback help")) {
                Text(model.t("40 hours is an optional plan, not a universal requirement or a guarantee of sound improvement."))
                Text(model.t("⌘Return: start, pause or resume · ⌘.: stop · ⌘1–4: switch screens"))
                Text(model.t("Run with earphones out of your ears. Start with low system/DAC volume."))
                Text(model.t("Use Session history to copy a result when reporting a problem. Nothing is uploaded automatically."))
                Text(model.t("Music supports local files readable by macOS: mono or stereo, 8–96 kHz, up to 10 minutes selected."))
                Text(model.t("External music is band-limited and faded for this playback path; it is not unprocessed listening playback."))
            }
        }.sheet(isPresented: $changelog) {
            DetailSheet(title: model.t("Changelog"), done: model.t("Done")) { HistoryView(model: model) }
        }
    }
}

import SwiftUI
import AppKit

@MainActor struct PlaybackCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    private var primaryLabel: String {
        model.state == .playing ? "Pause" : model.state == .paused ? "Resume" : "Start"
    }
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(model.t("Settings")) { show(3) }.keyboardShortcut(",", modifiers: .command)
        }
        CommandMenu(model.t("Playback")) {
            Button(model.t(primaryLabel)) {
                if [.playing, .paused].contains(model.state) { model.togglePause() }
                else if model.canStart { model.start() }
            }.keyboardShortcut(.return, modifiers: .command)
                .disabled(!model.canStart && ![.playing, .paused].contains(model.state))
            Button(model.t("Stop"), action: model.stop).keyboardShortcut(".", modifiers: .command)
                .disabled((!model.state.locksSettings && model.armed == nil) || model.state == .stopping)
            Divider()
            Button(model.t("Quick Play")) { show(0) }.keyboardShortcut("1", modifiers: .command)
            Button(model.t("Music")) { show(1) }.keyboardShortcut("2", modifiers: .command)
            Button(model.t("Output")) { show(2) }.keyboardShortcut("3", modifiers: .command)
            Button(model.t("Settings")) { show(3) }.keyboardShortcut("4", modifiers: .command)
        }
    }
    private func show(_ tab: Int) {
        model.tab = tab; openWindow(id: "main"); NSApp.activate()
    }
}

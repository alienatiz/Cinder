import SwiftUI
import AppKit

@MainActor struct PlaybackCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(model.t("Settings")) { show(3) }.keyboardShortcut(",", modifiers: .command)
        }
        CommandMenu(model.t("Playback")) {
            Button(model.t(model.primaryPlaybackTitle), action: model.performPrimaryPlaybackAction)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!model.canPerformPrimaryPlaybackAction)
            Button(model.t("Stop"), action: model.stop).keyboardShortcut(".", modifiers: .command)
                .disabled(!model.canStop)
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

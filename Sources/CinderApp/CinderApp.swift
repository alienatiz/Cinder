import SwiftUI
import AppKit
import CinderCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var onQuit: (() -> Void)?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { onQuit?() }
}

@main @MainActor struct CinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window(Identity.name, id: "main") {
            RootView(model: model)
                .frame(minWidth: 1180, minHeight: 740)
                .preferredColorScheme(model.appearance == "system" ? nil : (model.appearance == "dark" ? .dark : .light))
                .onAppear { model.applyNativeAppearance(); delegate.onQuit = { model.shutdown() }; NSApp.activate() }
                .onChange(of: model.language) { _, _ in model.saveUI() }
                .onChange(of: model.appearance) { _, _ in model.saveUI() }
                .onChange(of: model.needle) { _, _ in model.saveUI() }
                .onChange(of: model.selectedUID) { _, _ in model.refreshOutputInfo(); model.saveUI() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.active(true) }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in model.active(false) }
        }
        .defaultSize(width: 1280, height: 800)
    }
}

import SwiftUI
import AppKit
import CinderCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationDidBecomeActive(_ notification: Notification) { model?.active(true) }
    func applicationDidResignActive(_ notification: Notification) { model?.active(false) }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}

@main @MainActor struct CinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window(Identity.name, id: "main") {
            RootView(model: model)
                .frame(minWidth: 1180, minHeight: 740)
                .preferredColorScheme(model.appearance == "system" ? nil : (model.appearance == "dark" ? .dark : .light))
                .onAppear {
                    delegate.model = model
                    model.mainWindowVisible(true)
                    model.applyNativeAppearance()
                    NSApp.activate()
                }
                .onDisappear { model.mainWindowVisible(false) }
                .onChange(of: model.language) { _, _ in model.saveUI() }
                .onChange(of: model.appearance) { _, _ in model.saveUI() }
                .onChange(of: model.needle) { _, _ in model.saveUI() }
                .onChange(of: model.selectedUID) { _, _ in model.refreshOutputInfo(); model.saveUI() }
        }
        .defaultSize(width: 1280, height: 800)

        MenuBarExtra {
            MenuBarStatusView(model: model)
        } label: {
            Image(systemName: "flame.fill")
                .accessibilityLabel(Text("Cinder"))
                .help(model.t("Cinder status and controls"))
                .onAppear { delegate.model = model }
        }
        .menuBarExtraStyle(.window)
    }
}

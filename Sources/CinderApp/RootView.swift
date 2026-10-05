import SwiftUI
import CinderCore
import CinderPlatform

struct RootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var systemColorScheme
    private let tabs = ["Quick Play", "Music", "Output", "Settings"]
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(Identity.name).font(.title3.weight(.semibold))
                Picker(model.t("Navigation"), selection: $model.tab) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, name in Text(model.t(name)).tag(index) }
                }.pickerStyle(.segmented).labelsHidden()
                HStack(spacing: 3) {
                    Text("v\(Identity.version)").foregroundStyle(.secondary).fixedSize()
                    InfoHint(text: model.t("Development help"))
                }
            }.fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Group {
                switch model.tab {
                case 1: MusicView(model: model)
                case 2: DeviceView(model: model)
                case 3: SettingsView(model: model)
                default: QuickPlayView(model: model)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if let error = model.error {
                HStack { Image(systemName: "exclamationmark.triangle"); Text(error).textSelection(.enabled); Spacer(); Button(model.t("Dismiss")) { model.error = nil } }
                    .lineLimit(3).help(error)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 14) {
                Button(model.t("Start"), action: model.start).buttonStyle(CinderButtonStyle(prominent: true)).disabled(!model.canStart)
                Button(model.t(model.state == .paused ? "Resume" : "Pause"), action: model.togglePause).disabled(!model.canTogglePause)
                Button(model.t("Stop"), action: model.stop).disabled(!model.canStop)
            }.controlSize(.large).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Text(model.planRun?.nextStart != nil ? model.t("Resting between sessions") : model.armed != nil ? model.t("Waiting for scheduled start — no sound") : model.t(model.state.rawValue)).foregroundStyle(.secondary)
        }
        .font(.system(size: 13)).padding(24)
        .background(model.customTheme.map { Color(hex: $0.colors["window.background"]!) } ?? Color(nsColor: .windowBackgroundColor))
        .foregroundStyle(model.customTheme.map { Color(hex: $0.colors["text.primary"]!) } ?? Color.primary)
        .tint(model.customTheme.map { Color(hex: $0.colors["accent"]!) } ?? Color.accentColor)
        .buttonStyle(CinderButtonStyle())
        .environment(\.cinderTheme, model.customTheme)
        .environment(\.colorScheme, model.customTheme.map { $0.prefersDark ? .dark : .light } ?? systemColorScheme)
    }
}

struct DevicePicker: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack {
            Picker(model.t("Output device"), selection: Binding(get: { model.selectedUID }, set: { model.selectOutput($0) })) {
                Text(model.t("Select output")).tag("")
                ForEach(model.devices) { device in Text(device.name).tag(device.uid) }
            }
            Button(model.t("Refresh"), action: model.refreshDevices)
        }.disabled(model.isLocked)
    }
}

struct Panel<Content: View>: View {
    @Environment(\.cinderTheme) private var theme
    let title: String
    let compact: Bool
    let content: Content
    init(title: String, compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title; self.compact = compact; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Text(title).font(.headline)
            content
        }.padding(compact ? 16 : 22).frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                if let theme { RoundedRectangle(cornerRadius: 16).fill(Color(hex: theme.colors["control.background"]!)) }
                else { RoundedRectangle(cornerRadius: 16).fill(.regularMaterial) }
            }
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.08)))
    }
}

@MainActor struct QuickPlayView: View {
    @ObservedObject var model: AppModel
    @State private var scheduling = false
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                DevicePicker(model: model)
                Button(model.t("Output details")) { model.tab = 2 }
                Button(model.t("Schedule")) { scheduling = true }
                if model.armed != nil { Button(model.t("Cancel Schedule"), action: model.cancelSchedule) }
                Spacer()
                if model.settings.selectedProgram.usesMusic {
                    Text(model.musicSummary).foregroundStyle(.secondary).lineLimit(1)
                    Button(model.t("Music")) { model.tab = 1 }
                }
            }
            PlaybackPlanView(model: model)
            if let issue = model.musicProblem { Text(issue).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            HStack(alignment: .top, spacing: 16) {
                CurrentProgressView(model: model)
                VStack(spacing: 12) {
                    DigitalOutputView(model: model)
                    GainPresetView(model: model)
                }
            }
            Text(model.t("Run with earphones out of your ears. Start with low system/DAC volume.")).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $scheduling) {
            DetailSheet(title: model.t("Schedule"), done: model.t("Done")) { ScheduleView(model: model) }
        }
    }
}

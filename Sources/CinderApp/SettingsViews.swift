import SwiftUI
import AppKit
import CinderCore
import CinderPlatform

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var category = 0
    @State private var editingTheme = false
    var body: some View {
        VStack(spacing: 20) {
            Picker(model.t("Settings"), selection: $category) {
                Text(model.t("Playback & Presets")).tag(0)
                Text(model.t("Language & Appearance")).tag(1)
                Text(model.t("Updates")).tag(2)
                Text(model.t("Notifications")).tag(3)
                Text(model.t("Session history")).tag(4)
                Text(model.t("About Cinder")).tag(5)
            }.pickerStyle(.segmented)
            if category == 0 { PlaybackSettingsView(model: model) }
            else if category == 1 {
                HStack(alignment: .top, spacing: 22) {
                    Panel(title: model.t("Language")) {
                        Picker(model.t("Language"), selection: $model.language) {
                            Text("English").tag("en"); Text("한국어").tag("ko"); Text("日本語").tag("ja")
                        }
                        Text(model.t("UI settings are saved automatically."))
                    }
                    Panel(title: model.t("Appearance")) {
                        Picker(model.t("Theme"), selection: Binding(get: { model.themeChoice }, set: { model.themeChoice = $0; model.chooseTheme() })) {
                            Text(model.t("System")).tag("system"); Text(model.t("Light")).tag("light"); Text(model.t("Dark")).tag("dark")
                            ForEach(model.themes) { theme in Text(theme.name).tag(theme.id) }
                            if model.themeChoice == "custom" { Text(model.t("Custom")).tag("custom") }
                        }
                        Button(model.t("Theme Editor")) { editingTheme = true }
                        Toggle(model.t("Needle meter"), isOn: $model.needle)
                        Toggle(model.t("Audiophile details"), isOn: $model.audiophile).onChange(of: model.audiophile) { _, _ in model.saveTheme() }
                        Text(model.t("Meter style changes visualization only. Values remain digital dBFS."))
                    }
                }
            } else if category == 2 { UpdateSettingsView(model: model) }
            else if category == 3 { NotificationSettingsView(model: model) }
            else if category == 4 { SessionHistoryView(model: model) }
            else { AboutView(model: model) }
        }.sheet(isPresented: $editingTheme) {
            DetailSheet(title: model.t("Theme Editor"), done: model.t("Done")) { ThemeEditorView(model: model) }
        }
    }
}

struct PlaybackSettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 18) {
            Panel(title: model.t("Playback")) {
                DurationPicker(model: model)
                Text(model.t("Duration includes rest periods."))
                Toggle(model.t("Keep Mac awake during playback"), isOn: $model.settings.keepAwake)
                Button(model.t("Save settings"), action: model.save)
            }.disabled(model.isLocked)
            Panel(title: model.t("Presets")) {
                Picker(model.t("Preset"), selection: $model.presetSelection) {
                    Text(model.t("Select preset")).tag("")
                    ForEach(model.presets) { preset in Text(preset.id).tag(preset.id) }
                }
                HStack {
                    Button(model.t("Apply")) { if let preset = model.presets.first(where: { $0.id == model.presetSelection }) { model.applyPreset(preset) } }
                    Button(model.t("Save As"), action: model.saveNamedPreset)
                    Button(model.t("Export…"), action: model.exportPreset)
                    Button(model.t("Import…"), action: model.importPreset)
                }
                TextField(model.t("Preset name"), text: $model.presetName)
                Text(model.t("Preset applied. Playback and scheduling remain manual."))
                Text(model.message).foregroundStyle(.secondary).textSelection(.enabled)
            }.disabled(model.isLocked)
        }
    }
}

struct ScheduleView: View {
    @ObservedObject var model: AppModel
    @State private var presets = false
    var body: some View {
        VStack(spacing: 18) {
            Picker(model.t("Schedule"), selection: $presets) {
                Text(model.t("Schedule")).tag(false)
                Text(model.t("Scheduling Preset")).tag(true)
            }.pickerStyle(.segmented)
            if !presets { Panel(title: model.t("Schedule"), compact: true) {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        DatePicker(model.t("Start date"), selection: $model.scheduleDate, displayedComponents: .date).datePickerStyle(.graphical)
                        DatePicker(model.t("Start time"), selection: $model.scheduleDate, displayedComponents: .hourAndMinute)
                    }.disabled(model.isLocked)
                    VStack(alignment: .leading, spacing: 12) {
                        Picker(model.t("Execution"), selection: Binding(get: { model.repeatDays > 0 }, set: { repeating in
                            model.repeatDays = repeating ? 1 : 0
                            model.sessionCount = repeating ? max(2, model.sessionCount) : 1
                        })) {
                            Text(model.t("Once")).tag(false)
                            Text(model.t("Repeat")).tag(true)
                        }.pickerStyle(.segmented).disabled(model.isLocked)
                        if model.repeatDays > 0 {
                            Stepper(value: $model.repeatDays, in: 1...365) {
                                Text(model.t("Interval (days)") + " · \(model.repeatDays)")
                            }.disabled(model.isLocked)
                            Stepper(value: $model.sessionCount, in: 1...365) {
                                Text(model.t("Total runs") + " · \(model.sessionCount)")
                            }.disabled(model.isLocked)
                            Text(model.t("Total runs includes the first run. Interval 1 means every day."))
                        }
                        Text(model.t("Output device") + " · " + (model.device?.name ?? model.t("Select output")))
                        Text(model.t("Duration per run") + " · " + Cycle.time(Double(model.settings.planElapsedMinutes * 60))).monospacedDigit()
                        if model.settings.selectedPlan.mode == .split40 {
                            Text(model.t("Each scheduled run executes the entire 40-hour plan, including its rests."))
                        }
                        Text(model.t(model.settings.selectedProgram.label))
                        if let target = model.armed {
                            Text(model.t("Next scheduled start") + " · " + target.formatted(date: .abbreviated, time: .shortened))
                        }
                        if !model.scheduleMessage.isEmpty { Text(model.scheduleMessage) }
                        if model.repeatRemaining > 0 { Text(model.t("Remaining sessions") + " · \(model.repeatRemaining)") }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack {
                    Button(model.t("Set Schedule"), action: model.setSchedule).disabled(model.isLocked || model.device == nil || model.musicProblem != nil)
                    Button(model.t("Cancel Schedule"), action: model.cancelSchedule).disabled(model.armed == nil && model.repeatRemaining == 0)
                }
                if let issue = model.musicProblem { Text(issue).foregroundStyle(.orange) }
                if model.repeatDays > 0 && model.settings.planElapsedMinutes >= model.repeatDays * 24 * 60 {
                    Text(model.t("Sessions overlap this interval; conflicting dates will be skipped.")).foregroundStyle(.orange)
                }
                Text(model.t("Keep the app open. Sleeping or closed Macs are not automatically awakened.")).foregroundStyle(.secondary)
                Text(model.t("Late starts over 60 seconds are cancelled. Repeats skip overlapping sessions.")).foregroundStyle(.secondary)
            }
            } else { Panel(title: model.t("Scheduling Preset"), compact: true) {
                HStack {
                    Picker(model.t("Preset"), selection: $model.schedulingPresetSelection) {
                        Text(model.t("Select preset")).tag("")
                        ForEach(model.schedulingPresets) { preset in Text(preset.name).tag(preset.id) }
                    }
                    TextField(model.t("Preset name"), text: $model.schedulingPresetName)
                }
                HStack {
                    Button(model.t("Apply")) { if let preset = model.schedulingPresets.first(where: { $0.id == model.schedulingPresetSelection }) { model.applySchedulingPreset(preset) } }
                    Button(model.t("Save As"), action: model.saveSchedulingPreset)
                    Button(model.t("Export…"), action: model.exportSchedulingPreset)
                    Button(model.t("Import…"), action: model.importSchedulingPreset)
                }
                Text(model.t("Saves local time and repetition only. Playback settings stay unchanged."))
            }.disabled(model.isLocked)
            }
        }.environment(\.locale, Locale(identifier: model.language))
    }
}

struct ThemeEditorView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            Panel(title: model.t("Theme files")) {
                Text(model.t("Choose a theme in Language & Appearance. Edit its colors here."))
                HStack { Button(model.t("Import…"), action: model.importTheme); Button(model.t("Export…"), action: model.exportTheme) }
                Text(model.t("Theme colors are saved automatically. Native controls follow macOS appearance."))
            }
            Panel(title: model.t("Theme Editor")) {
                Picker(model.t("Color"), selection: $model.colorToken) { ForEach(ThemeDocument.tokens, id: \.self) { Text($0).tag($0) } }
                    .onChange(of: model.colorToken) { _, token in model.hexColor = model.effectiveTheme?.colors[token] ?? "#E3AD59" }
                ColorPicker(model.t("Color"), selection: Binding(get: { Color(hex: model.hexColor) }, set: { color in
                    guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                    model.editColor(String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded())))
                }), supportsOpacity: false)
                HStack { TextField("#RRGGBB", text: $model.hexColor); Button(model.t("Apply")) { model.editColor(model.hexColor) } }
            }
        }.onAppear { model.hexColor = model.effectiveTheme?.colors[model.colorToken] ?? "#E3AD59" }
    }
}

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var selected = Identity.version
    @State private var page = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(model.t("Version"), selection: $selected) {
                ForEach(model.releases) { release in Text(release.version).tag(release.version) }
            }.onChange(of: selected) { _, _ in page = 0 }
            if model.releases.isEmpty { Text(model.t("Version history could not be loaded. Rebuild the app with its resources.")) }
            if let release = model.releases.first(where: { $0.version == selected }) {
                let entries = release.changes[model.language] ?? release.changes["en"] ?? []
                ForEach(Array(entries.enumerated()).dropFirst(page * 4).prefix(4), id: \.offset) { _, change in
                    Text("• \(change.type) — \(change.text)").frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                PageControls(model: model, page: $page, count: (entries.count + 3) / 4)
            }
        }.textSelection(.enabled)
    }
}
